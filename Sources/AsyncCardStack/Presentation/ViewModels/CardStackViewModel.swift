//
//  CardStackViewModel.swift
//  AsyncCardStack
//
//  Created by Software Architect on 2025-08-23.
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
  
  // Async stream handling
  private var updateTask: Task<Void, Never>?
  private var loadMoreTask: Task<Void, Never>?
  
  // Callbacks
  public var onSwipe: ((Element, Direction) async -> Bool)?
  public var onUndo: ((Element) async -> Bool)?
  
  // MARK: - Initialization
  
  public init(
    dataSource: DataSource,
    configuration: CardStackConfiguration = .default
  ) {
    self.dataSource = dataSource
    self.configuration = configuration
    self.state = CardStackState(configuration: configuration)
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
        // Load initial cards
        state.setLoading(true)
        let initialCards = try await dataSource.loadInitialCards()
        state.setCards(initialCards)
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
    guard let card = state.swipe(direction: direction) else { return }
    
    // Check if we should load more cards
    if state.shouldPreloadMore {
      await loadMoreCardsIfNeeded()
    }
    
    // Report swipe to data source
    do {
      // Call custom swipe handler if provided
      if let onSwipe = onSwipe {
        let shouldProceed = await onSwipe(card, direction)
        if !shouldProceed {
          // Undo the swipe if handler returns false
          _ = state.undo()
          return
        }
      }
      
      try await dataSource.reportSwipe(card: card, direction: direction)
    } catch {
      // If reporting fails, optionally undo the swipe
      _ = state.undo()
      state.setError(error)
    }
  }
  
  /// Undo the last swipe
  public func undo() async {
    guard let card = state.undo() else { return }
    
    do {
      // Call custom undo handler if provided
      if let onUndo = onUndo {
        let shouldProceed = await onUndo(card)
        if !shouldProceed {
          // Re-swipe if handler returns false
          if let lastAction = state.swipeHistory.last {
            _ = state.swipe(direction: lastAction.direction)
          }
          return
        }
      }
      
      try await dataSource.reportUndo(card: card)
    } catch {
      // If reporting fails, re-apply the swipe
      if let lastAction = state.swipeHistory.last {
        _ = state.swipe(direction: lastAction.direction)
      }
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
      state.setCards(cards)
      
    case .append(let cards):
      state.appendCards(cards)
      
    case .replace(let cards):
      state.setCards(cards)
      
    case .remove(let ids):
      state.removeCards(ids: ids)
      
    case .clear:
      state.clearCards()
      
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
    configuration: CardStackConfiguration = .default
  ) where DataSource == StaticCardDataSource<Element> {
    let dataSource = StaticCardDataSource(cards: cards)
    self.init(dataSource: dataSource, configuration: configuration)
  }
  
  /// Initialize with an async sequence of cards
  public convenience init<S: AsyncSequence>(
    cardSequence: S,
    configuration: CardStackConfiguration = .default
  ) where DataSource == AsyncSequenceDataSource<Element, S>, S.Element == [Element] {
    let dataSource = AsyncSequenceDataSource(sequence: cardSequence)
    self.init(dataSource: dataSource, configuration: configuration)
  }
}