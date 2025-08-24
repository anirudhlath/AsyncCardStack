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
    updateTask?.cancel()
    
    updateTask = Task { [weak self] in
      guard let self = self else { return }
      
      do {
        // Restore tombstones if configured
        await state.restoreTombstones()
        
        // Load initial cards
        state.setLoading(true)
        let initialCards = try await dataSource.loadInitialCards()
        await state.setCards(initialCards)
        state.setLoading(false)
        
        // Listen to updates
        for await update in try await dataSource.cardStream {
          guard !Task.isCancelled else { break }
          await self.handleUpdate(update)
        }
      } catch {
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
    // Use the new async swipe method
    guard let card = await state.swipe(direction: direction) else { return }
    
    // Check if we should load more cards
    if state.shouldPreloadMore {
      await loadMoreCardsIfNeeded()
    }
    
    // Report swipe to data source
    do {
      try await dataSource.reportSwipe(card: card, direction: direction)
    } catch {
      // If reporting fails, optionally undo the swipe
      _ = await state.undo()
      state.setError(error)
    }
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
    switch update {
    case .initial(let cards):
      await state.setCards(cards)
      
    case .append(let cards):
      state.appendCards(cards)
      
    case .replace(let cards):
      await state.setCards(cards)
      
    case .remove(let ids):
      state.removeCards(ids: ids)
      
    case .clear:
      await state.clearCards()
      
    case .update(let card):
      state.updateCard(card)
    }
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