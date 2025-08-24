//
//  CardStackViewModel.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import Foundation
import SwiftUI

/// ViewModel that manages the card stack using Swift concurrency
@MainActor
public final class CardStackViewModel<Element: CardElement, Direction: SwipeDirection, DataSource: CardDataSource>: ObservableObject where DataSource.Element == Element {
  
  // MARK: - Properties
  
  @Published public private(set) var state: CardStackState<Element, Direction>
  
  private let dataSource: DataSource
  private let configuration: CardStackConfiguration
  private let undoConfiguration: UndoConfiguration<Element, Direction>?
  
  // Async stream handling
  private var updateTask: Task<Void, Never>?
  private var loadMoreTask: Task<Void, Never>?
  
  // MARK: - Initialization
  
  public init(
    dataSource: DataSource,
    configuration: CardStackConfiguration = .default,
    undoConfiguration: UndoConfiguration<Element, Direction>? = nil
  ) {
    self.dataSource = dataSource
    self.configuration = configuration
    self.undoConfiguration = undoConfiguration
    self.state = CardStackState(
      configuration: configuration,
      undoConfiguration: undoConfiguration
    )
  }
  
  deinit {
    updateTask?.cancel()
    loadMoreTask?.cancel()
  }
  
  // MARK: - Public Methods
  
  /// Start listening to card updates
  public func startListening() {
    print("🚀 CardStackViewModel: startListening() called")
    updateTask?.cancel()
    
    updateTask = Task { [weak self] in
      guard let self = self else { 
        print("🔴 CardStackViewModel: self is nil in Task")
        return 
      }
      
      do {
        print("🚀 CardStackViewModel: Restoring tombstones...")
        // Restore tombstones if configured
        await state.restoreTombstones()
        
        print("🚀 CardStackViewModel: Loading initial cards...")
        // Load initial cards
        state.setLoading(true)
        let initialCards = try await dataSource.loadInitialCards()
        print("🚀 CardStackViewModel: Loaded \(initialCards.count) initial cards")
        await state.setCards(initialCards)
        state.setLoading(false)
        
        print("🚀 CardStackViewModel: Setting up card stream...")
        // Listen to updates
        for await update in try await dataSource.cardStream {
          guard !Task.isCancelled else { 
            print("🟡 CardStackViewModel: Task cancelled, breaking stream loop")
            break 
          }
          print("🚀 CardStackViewModel: Received update from stream")
          await self.handleUpdate(update)
        }
      } catch {
        print("🔴 CardStackViewModel: Error in startListening: \(error)")
        state.setError(error)
      }
    }
  }
  
  /// Stop listening to updates
  public func stopListening() {
    updateTask?.cancel()
    updateTask = nil
    loadMoreTask?.cancel()
    loadMoreTask = nil
  }
  
  /// Swipe a card in the given direction
  public func swipe(direction: Direction) async {
    print("🎯 CardStackViewModel.swipe: Starting swipe with direction: \(direction)")
    print("🎯 CardStackViewModel.swipe: Current visibleCards count: \(state.visibleCards.count)")
    print("🎯 CardStackViewModel.swipe: Current card: \(String(describing: state.currentCard?.id))")
    
    // Use the new async swipe method
    guard let card = await state.swipe(direction: direction) else { 
      print("🔴 CardStackViewModel.swipe: state.swipe returned nil")
      return 
    }
    
    print("🎯 CardStackViewModel.swipe: Successfully swiped card: \(String(describing: card.id))")
    print("🎯 CardStackViewModel.swipe: After swipe - visibleCards count: \(state.visibleCards.count)")
    
    // Check if we should load more cards
    if state.shouldPreloadMore {
      print("🎯 CardStackViewModel.swipe: Loading more cards (shouldPreloadMore = true)")
      await loadMoreCardsIfNeeded()
    }
    
    // Report swipe to data source
    do {
      print("🎯 CardStackViewModel.swipe: Reporting swipe to dataSource")
      try await dataSource.reportSwipe(card: card, direction: direction)
      print("✅ CardStackViewModel.swipe: Successfully reported swipe to dataSource")
    } catch {
      print("🔴 CardStackViewModel.swipe: Failed to report swipe: \(error)")
      // If reporting fails, optionally undo the swipe
      _ = await state.undo()
      state.setError(error)
    }
    
    print("🎯 CardStackViewModel.swipe: Swipe complete - final visibleCards count: \(state.visibleCards.count)")
  }
  
  /// Undo the last swipe
  public func undo() async {
    // Use the new async undo method with validation
    guard let card = await state.undo() else { return }
    
    do {
      try await dataSource.reportUndo(card: card)
    } catch {
      // If reporting fails, we can't re-apply since state already changed
      // Just log the error
      state.setError(error)
    }
  }
  
  /// Manually trigger loading more cards
  public func loadMoreCards() async {
    await loadMoreCardsIfNeeded()
  }
  
  // MARK: - Private Methods
  
  private func handleUpdate(_ update: CardUpdate<Element>) async {
    print("📦 CardStackViewModel.handleUpdate: Received update")
    
    switch update {
    case .initial(let cards):
      print("📦 CardStackViewModel.handleUpdate: .initial with \(cards.count) cards")
      await state.setCards(cards)
      
    case .append(let cards):
      print("📦 CardStackViewModel.handleUpdate: .append with \(cards.count) cards")
      state.appendCards(cards)
      
    case .replace(let cards):
      print("📦 CardStackViewModel.handleUpdate: .replace with \(cards.count) cards")
      await state.setCards(cards)
      
    case .remove(let ids):
      print("📦 CardStackViewModel.handleUpdate: .remove with \(ids.count) card IDs")
      print("📦 CardStackViewModel.handleUpdate: IDs to remove: \(ids)")
      state.removeCards(ids: ids)
      print("📦 CardStackViewModel.handleUpdate: After removal - visibleCards: \(state.visibleCards.count)")
      
    case .clear:
      print("📦 CardStackViewModel.handleUpdate: .clear")
      await state.clearCards()
      
    case .update(let card):
      print("📦 CardStackViewModel.handleUpdate: .update for card: \(card.id)")
      state.updateCard(card)
    }
    
    print("📦 CardStackViewModel.handleUpdate: Update complete - current visibleCards: \(state.visibleCards.count)")
  }
  
  private func loadMoreCardsIfNeeded() async {
    // Prevent multiple concurrent load operations
    guard loadMoreTask == nil else { return }
    
    loadMoreTask = Task { [weak self] in
      guard let self = self else { return }
      
      do {
        let moreCards = try await dataSource.loadMoreCards()
        if !moreCards.isEmpty {
          state.appendCards(moreCards)
        }
      } catch {
        // Silently fail for load more operations
        print("Failed to load more cards: \(error)")
      }
      
      self.loadMoreTask = nil
    }
    
    await loadMoreTask?.value
  }
}

// MARK: - Convenience Initializers

extension CardStackViewModel {
  /// Initialize with a static array of cards
  public convenience init(
    cards: [Element],
    configuration: CardStackConfiguration = .default,
    undoConfiguration: UndoConfiguration<Element, Direction>? = nil
  ) where DataSource == StaticCardDataSource<Element> {
    let dataSource = StaticCardDataSource(cards: cards)
    self.init(
      dataSource: dataSource,
      configuration: configuration,
      undoConfiguration: undoConfiguration
    )
  }
  
  /// Initialize with an async sequence of cards
  public convenience init<S: AsyncSequence>(
    cardSequence: S,
    configuration: CardStackConfiguration = .default,
    undoConfiguration: UndoConfiguration<Element, Direction>? = nil
  ) where DataSource == AsyncSequenceDataSource<Element, S>, S.Element == [Element] {
    let dataSource = AsyncSequenceDataSource(sequence: cardSequence)
    self.init(
      dataSource: dataSource,
      configuration: configuration,
      undoConfiguration: undoConfiguration
    )
  }
}