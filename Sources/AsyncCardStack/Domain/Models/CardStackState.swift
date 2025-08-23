//
//  CardStackState.swift
//  AsyncCardStack
//
//  Created by Software Architect on 2025-08-23.
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

/// State management for the card stack
@MainActor
public final class CardStackState<Element: CardElement, Direction: SwipeDirection>: ObservableObject {
  // MARK: - Published Properties
  
  @Published private(set) public var cards: [Element] = []
  @Published private(set) public var currentIndex: Int = 0
  @Published private(set) public var swipeHistory: [SwipeAction<Element, Direction>] = []
  @Published private(set) public var isLoading: Bool = false
  @Published private(set) public var error: Error?
  
  // MARK: - Internal State
  
  internal var cardData: [CardData<Element, Direction>] = []
  private let configuration: CardStackConfiguration
  
  // MARK: - Computed Properties
  
  public var currentCard: Element? {
    guard currentIndex < cards.count else { return nil }
    return cards[currentIndex]
  }
  
  public var remainingCards: Int {
    max(0, cards.count - currentIndex)
  }
  
  public var canUndo: Bool {
    configuration.enableUndo && currentIndex > 0
  }
  
  public var visibleCards: [Element] {
    guard currentIndex < cards.count else { return [] }
    let endIndex = min(currentIndex + configuration.maxVisibleCards, cards.count)
    return Array(cards[currentIndex..<endIndex])
  }
  
  // MARK: - Initialization
  
  public init(configuration: CardStackConfiguration = .default) {
    self.configuration = configuration
  }
  
  // MARK: - Card Management
  
  /// Set cards (replaces all existing cards)
  public func setCards(_ newCards: [Element]) {
    cards = newCards
    cardData = newCards.map { CardData(element: $0) }
    currentIndex = newCards.isEmpty ? 0 : min(currentIndex, newCards.count - 1)
    swipeHistory.removeAll()
  }
  
  /// Append new cards to the end
  public func appendCards(_ newCards: [Element]) {
    let uniqueNewCards = newCards.filter { newCard in
      !cards.contains { $0.id == newCard.id }
    }
    
    cards.append(contentsOf: uniqueNewCards)
    cardData.append(contentsOf: uniqueNewCards.map { CardData(element: $0) })
  }
  
  /// Update a specific card
  public func updateCard(_ card: Element) {
    guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
    cards[index] = card
    cardData[index] = CardData(element: card, swipeDirection: cardData[index].swipeDirection)
  }
  
  /// Remove cards by IDs
  public func removeCards(ids: Set<Element.ID>) {
    cards.removeAll { ids.contains($0.id) }
    cardData.removeAll { ids.contains($0.id) }
    
    // Adjust current index if needed
    if currentIndex >= cards.count {
      currentIndex = max(0, cards.count - 1)
    }
  }
  
  /// Clear all cards
  public func clearCards() {
    cards.removeAll()
    cardData.removeAll()
    currentIndex = 0
    swipeHistory.removeAll()
  }
  
  // MARK: - Swipe Actions
  
  /// Process a swipe action
  public func swipe(direction: Direction) -> Element? {
    guard currentIndex < cards.count else { return nil }
    
    let card = cards[currentIndex]
    cardData[currentIndex].swipeDirection = direction
    
    let action = SwipeAction(card: card, direction: direction)
    swipeHistory.append(action)
    
    currentIndex += 1
    return card
  }
  
  /// Undo the last swipe
  public func undo() -> Element? {
    guard canUndo else { return nil }
    
    currentIndex -= 1
    let card = cards[currentIndex]
    cardData[currentIndex].swipeDirection = nil
    
    if !swipeHistory.isEmpty {
      swipeHistory.removeLast()
    }
    
    return card
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
    guard let absoluteIndex = cards.firstIndex(where: { $0.id == cardId }) else { return nil }
    let relativeIndex = absoluteIndex - currentIndex
    return relativeIndex >= 0 && relativeIndex < configuration.maxVisibleCards ? relativeIndex : nil
  }
  
  /// Check if we should preload more cards
  public var shouldPreloadMore: Bool {
    remainingCards <= configuration.preloadThreshold
  }
}