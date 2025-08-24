//
//  CardStackState.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import Foundation

/// Internal card data wrapper
@MainActor
internal final class CardData<Element: CardElement, Direction: SwipeDirection>: Identifiable {
  let id: Element.ID
  let element: Element
  var swipeDirection: Direction?
  
  init(element: Element, swipeDirection: Direction? = nil) {
    self.id = element.id
    self.element = element
    self.swipeDirection = swipeDirection
  }
}

/// State management for the card stack with immutable ID tracking
@MainActor
public final class CardStackState<Element: CardElement, Direction: SwipeDirection>: ObservableObject {
  // MARK: - Published Properties
  
  @Published private(set) public var isLoading: Bool = false
  @Published private(set) public var error: Error?
  
  // MARK: - Immutable ID Tracking
  
  /// Ordered list of card IDs (immutable order)
  private var cardOrder: [Element.ID] = []
  
  /// Map of card IDs to actual card data
  private var cardsById: [Element.ID: Element] = [:]
  
  /// Current position in cardOrder
  private var currentPosition: Int = 0
  
  /// Tombstones for undo functionality
  private var tombstones: [Tombstone<Element, Direction>] = []
  
  /// Track swipe directions for animation
  private var swipedCards: [Element.ID: Direction] = [:]
  
  // MARK: - Configuration
  
  private let configuration: CardStackConfiguration
  private let undoConfiguration: UndoConfiguration<Element, Direction>?
  
  // MARK: - Computed Properties
  
  /// Currently visible cards (computed from position and order)
  public var cards: [Element] {
    cardOrder.compactMap { cardsById[$0] }
  }
  
  public var currentCard: Element? {
    guard currentPosition < cardOrder.count else { return nil }
    return cardsById[cardOrder[currentPosition]]
  }
  
  public var remainingCards: Int {
    max(0, cardOrder.count - currentPosition)
  }
  
  public var canUndo: Bool {
    guard undoConfiguration != nil else { return false }
    return !tombstones.isEmpty
  }
  
  public var undoableCount: Int {
    tombstones.count
  }
  
  public var visibleCards: [Element] {
    guard currentPosition < cardOrder.count else { return [] }
    let endIndex = min(currentPosition + configuration.maxVisibleCards, cardOrder.count)
    
    return cardOrder[currentPosition..<endIndex].compactMap { id in
      cardsById[id]
    }
  }
  
  /// Public access to swipe history (tombstones)
  public var swipeHistory: [SwipeAction<Element, Direction>] {
    tombstones.map { tombstone in
      SwipeAction(
        card: tombstone.card,
        direction: tombstone.direction,
        timestamp: tombstone.timestamp
      )
    }
  }
  
  // MARK: - Initialization
  
  public init(
    configuration: CardStackConfiguration = .default,
    undoConfiguration: UndoConfiguration<Element, Direction>? = nil
  ) {
    self.configuration = configuration
    self.undoConfiguration = undoConfiguration
  }
  
  // MARK: - Card Management
  
  /// Set cards (replaces all existing cards)
  public func setCards(_ newCards: [Element]) async {
    // Handle collection replacement based on strategy
    if let undoConfig = undoConfiguration, !tombstones.isEmpty {
      switch undoConfig.replacementStrategy {
      case .clearTombstones:
        // Clear all tombstones
        await evictAllTombstones()
        
      case .preserveValidTombstones:
        // Keep only tombstones that exist in new collection
        let newCardIds = Set(newCards.map { $0.id })
        let validTombstones = tombstones.filter { newCardIds.contains($0.id) }
        
        // Evict invalid tombstones
        for tombstone in tombstones where !newCardIds.contains(tombstone.id) {
          if let onEviction = undoConfig.onEviction {
            await onEviction(tombstone.card, tombstone.direction)
          }
        }
        
        tombstones = validTombstones
        
      case .blockIfTombstones:
        // Don't allow replacement if tombstones exist
        return
        
      case .askUser:
        // Ask for confirmation
        if let onConfirm = undoConfig.onConfirmReplacement {
          let confirmed = await onConfirm()
          if !confirmed { return }
        }
        await evictAllTombstones()
      }
    }
    
    // Update card tracking
    cardOrder = newCards.map { $0.id }
    cardsById = Dictionary(uniqueKeysWithValues: newCards.map { ($0.id, $0) })
    currentPosition = 0
  }
  
  /// Append new cards to the end
  public func appendCards(_ newCards: [Element]) {
    let uniqueNewCards = newCards.filter { newCard in
      !cardOrder.contains(newCard.id)
    }
    
    for card in uniqueNewCards {
      cardOrder.append(card.id)
      cardsById[card.id] = card
    }
  }
  
  /// Update a specific card
  public func updateCard(_ card: Element) {
    cardsById[card.id] = card
  }
  
  /// Remove cards by IDs
  public func removeCards(ids: Set<Element.ID>) {
    print("🔥 CardStackState.removeCards: Removing \(ids.count) cards")
    print("🔥 CardStackState.removeCards: Before - cardOrder.count = \(cardOrder.count), currentPosition = \(currentPosition)")
    
    // Remove from tracking
    for id in ids {
      cardsById.removeValue(forKey: id)
    }
    
    // Always remove from cardOrder to ensure UI updates
    // This is important when cards are removed from Firebase after swipe
    cardOrder.removeAll { ids.contains($0) }
    
    print("🔥 CardStackState.removeCards: After removal - cardOrder.count = \(cardOrder.count)")
    
    // Adjust position if needed
    // If current position is beyond the array, reset it
    if currentPosition >= cardOrder.count && !cardOrder.isEmpty {
      currentPosition = max(0, cardOrder.count - 1)
      print("🔥 CardStackState.removeCards: Adjusted currentPosition to \(currentPosition)")
    }
    
    // Skip over any missing cards
    while currentPosition < cardOrder.count && cardsById[cardOrder[currentPosition]] == nil {
      currentPosition += 1
      print("🔥 CardStackState.removeCards: Skipped missing card, currentPosition now \(currentPosition)")
    }
    
    print("🔥 CardStackState.removeCards: Final - visibleCards.count = \(visibleCards.count)")
    
    // Force UI update by triggering objectWillChange
    objectWillChange.send()
  }
  
  /// Clear all cards
  public func clearCards() async {
    await evictAllTombstones()
    cardOrder.removeAll()
    cardsById.removeAll()
    currentPosition = 0
    tombstones.removeAll()
  }
  
  // MARK: - Swipe Actions with Tombstones
  
  /// Process a swipe action with tombstone management
  public func swipe(direction: Direction) async -> Element? {
    print("🎨 CardStackState.swipe: Starting swipe")
    print("🎨 CardStackState.swipe: currentPosition = \(currentPosition), cardOrder.count = \(cardOrder.count)")
    print("🎨 CardStackState.swipe: visibleCards before swipe = \(visibleCards.count)")
    
    guard currentPosition < cardOrder.count else { 
      print("🔴 CardStackState.swipe: currentPosition >= cardOrder.count, returning nil")
      return nil 
    }
    
    let cardId = cardOrder[currentPosition]
    guard let card = cardsById[cardId] else { 
      print("🔴 CardStackState.swipe: Card not found in cardsById for id: \(cardId)")
      return nil 
    }
    
    // Store the swipe direction for animation
    swipedCards[cardId] = direction
    
    print("🎨 CardStackState.swipe: Swiping card: \(String(describing: cardId)) with direction: \(direction)")
    
    // Handle undo configuration
    if let undoConfig = undoConfiguration {
      // Add to tombstones
      let tombstone = Tombstone(card: card, direction: direction)
      tombstones.append(tombstone)
      
      // Persist tombstones after adding
      persistTombstones()
      
      // Check if we need to evict oldest tombstone
      if tombstones.count > undoConfig.limit {
        let evicted = tombstones.removeFirst()
        
        // Trigger eviction callback
        if let onEviction = undoConfig.onEviction {
          await onEviction(evicted.card, evicted.direction)
        }
        
        // Remove from tracking if not in current view
        if evicted.id != cardId {
          cardsById.removeValue(forKey: evicted.id)
        }
        
        // Persist after eviction
        persistTombstones()
      }
    }
    
    // Move position forward
    currentPosition += 1
    print("🎨 CardStackState.swipe: Moved currentPosition to \(currentPosition)")
    
    // Skip over any missing cards
    while currentPosition < cardOrder.count && cardsById[cardOrder[currentPosition]] == nil {
      currentPosition += 1
      print("🎨 CardStackState.swipe: Skipped missing card, currentPosition now \(currentPosition)")
    }
    
    print("🎨 CardStackState.swipe: After swipe - visibleCards = \(visibleCards.count)")
    print("🎨 CardStackState.swipe: After swipe - currentCard = \(String(describing: currentCard?.id))")
    
    // Force UI update by triggering objectWillChange
    objectWillChange.send()
    
    return card
  }
  
  /// Undo the last swipe with validation
  public func undo() async -> Element? {
    guard let undoConfig = undoConfiguration,
          !tombstones.isEmpty else { return nil }
    
    let tombstone = tombstones.last!
    
    // Verify card still exists
    guard let card = cardsById[tombstone.id] else {
      // Card was removed, remove invalid tombstone
      tombstones.removeLast()
      persistTombstones()
      // Try next tombstone recursively
      return await undo()
    }
    
    // Validate undo if needed
    if let validator = undoConfig.onUndoValidation {
      let canUndo = await validator(card)
      if !canUndo { return nil }
    }
    
    // Remove from tombstones
    tombstones.removeLast()
    persistTombstones()
    
    // Move position back
    currentPosition -= 1
    
    // Skip back over any missing cards
    while currentPosition > 0 && cardsById[cardOrder[currentPosition]] == nil {
      currentPosition -= 1
    }
    
    return card
  }
  
  // MARK: - Helper Methods
  
  /// Evict all tombstones
  private func evictAllTombstones() async {
    guard let undoConfig = undoConfiguration,
          let onEviction = undoConfig.onEviction else {
      tombstones.removeAll()
      return
    }
    
    for tombstone in tombstones {
      await onEviction(tombstone.card, tombstone.direction)
    }
    tombstones.removeAll()
  }
  
  // MARK: - State Management
  
  /// Set loading state
  public func setLoading(_ loading: Bool) {
    isLoading = loading
    if loading {
      error = nil
    }
  }
  
  /// Set error state
  public func setError(_ error: Error?) {
    self.error = error
    isLoading = false
  }
  
  // MARK: - Index Management
  
  /// Get the index of a card in the visible stack
  public func indexInStack(for cardId: Element.ID) -> Int? {
    // Find position in cardOrder
    guard let orderIndex = cardOrder.firstIndex(of: cardId) else { return nil }
    
    // Calculate relative position
    let relativeIndex = orderIndex - currentPosition
    
    // Check if it's in visible range
    return relativeIndex >= 0 && relativeIndex < configuration.maxVisibleCards ? relativeIndex : nil
  }
  
  /// Check if we should preload more cards
  public var shouldPreloadMore: Bool {
    remainingCards <= configuration.preloadThreshold
  }
  
  // MARK: - Tombstone Management
  
  /// Clear all tombstones (useful for logout, etc.)
  public func clearTombstones() async {
    await evictAllTombstones()
  }
  
  /// Get current tombstone count
  public var tombstoneCount: Int {
    tombstones.count
  }
  
  /// Check if a specific card is in tombstones
  public func isInTombstones(_ cardId: Element.ID) -> Bool {
    tombstones.contains { $0.id == cardId }
  }
  
  /// Get the swipe direction for a card (used for animation)
  public func getSwipeDirection(for cardId: Element.ID) -> Direction? {
    swipedCards[cardId]
  }
  
  // MARK: - Persistence
  
  /// Track if persistence warning has been shown for this instance
  private var persistenceWarningShown = false
  
  /// Check if types support persistence (runtime check)
  private var canPersist: Bool {
    // Check if Element and Direction conform to Codable at runtime
    // This uses Swift's runtime type checking
    let elementIsCodable = Element.self is any Codable.Type
    let directionIsCodable = Direction.self is any Codable.Type
    return elementIsCodable && directionIsCodable
  }
  
  /// Persist tombstones if possible
  private func persistTombstones() {
    guard let undoConfig = undoConfiguration,
          undoConfig.persistenceKey != nil else { return }
    
    // Check if persistence was requested but types don't support it
    if undoConfig.persistenceRequested && !canPersist && !tombstones.isEmpty {
      #if DEBUG
      // Only show warning once per instance
      if !persistenceWarningShown {
        persistenceWarningShown = true
        print("""
          ⚠️ AsyncCardStack Warning: Undo history cannot be persisted!
          
          Your card type does not conform to Codable.
          Undo history will be lost when the app terminates.
          
          To enable persistence:
          1. Make your card type conform to Codable:
             struct YourCard: CardElement, Codable { ... }
          
          2. Make your direction type conform to Codable:
             (LeftRight, FourDirections, and EightDirections already conform)
          
          This warning only appears in DEBUG builds.
          """)
      }
      #endif
    }
    
    // Only persist if types support Codable
    if canPersist {
      // Implementation for Codable types would go here
      // For now, we skip actual persistence implementation
    }
  }
  
  /// Load tombstones - returns empty array if persistence not available
  private func loadPersistedTombstones() -> [Tombstone<Element, Direction>] {
    guard let undoConfig = undoConfiguration,
          undoConfig.persistenceKey != nil,
          canPersist else {
      return []
    }
    
    // Implementation for loading Codable types would go here
    return []
  }
  
  /// Clear persisted tombstones
  private func clearPersistedTombstones() {
    guard let undoConfig = undoConfiguration,
          let persistenceKey = undoConfig.persistenceKey else { return }
    UserDefaults.standard.removeObject(forKey: persistenceKey)
  }
  
  /// Restore tombstones based on configuration
  public func restoreTombstones() async {
    guard let undoConfig = undoConfiguration else { return }
    
    let persistedTombstones = loadPersistedTombstones()
    
    switch undoConfig.restoreOnLaunch {
    case .restore:
      // Restore tombstones and keep them
      tombstones = persistedTombstones
      
      // Ensure cards are in cardsById
      for tombstone in tombstones {
        if cardsById[tombstone.id] == nil {
          cardsById[tombstone.id] = tombstone.card
        }
      }
      
      // Adjust current position to after tombstones
      let tombstoneIds = Set(tombstones.map { $0.id })
      var adjustedPosition = 0
      for id in cardOrder {
        if !tombstoneIds.contains(id) {
          break
        }
        adjustedPosition += 1
      }
      currentPosition = adjustedPosition
      
    case .clearGracefully:
      // Restore tombstones temporarily to evict them
      tombstones = persistedTombstones
      
      // Call onEviction for each tombstone
      if let onEviction = undoConfig.onEviction {
        for tombstone in tombstones {
          await onEviction(tombstone.card, tombstone.direction)
        }
      }
      
      // Clear tombstones after eviction
      tombstones.removeAll()
      clearPersistedTombstones()
      
    case .ignore:
      // Don't restore, just clear persisted data
      clearPersistedTombstones()
    }
  }
}