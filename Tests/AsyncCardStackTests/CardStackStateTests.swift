//
//  CardStackStateTests.swift
//  AsyncCardStackTests
//
//  Created by Test Engineer on 2025-08-23.
//

import XCTest
@testable import AsyncCardStack

// MARK: - Test Models

struct TestCard: CardElement, Codable, Equatable {
  let id: String
  let title: String
  let value: Int
  
  init(id: String = UUID().uuidString, title: String, value: Int = 0) {
    self.id = id
    self.title = title
    self.value = value
  }
}

// MARK: - CardStackState Tests

@MainActor
final class CardStackStateTests: XCTestCase {
  
  // MARK: - Properties
  
  private var sut: CardStackState<TestCard, LeftRight>!
  private var testCards: [TestCard]!
  
  // MARK: - Setup & Teardown
  
  override func setUp() async throws {
    try await super.setUp()
    
    testCards = [
      TestCard(id: "1", title: "Card 1", value: 1),
      TestCard(id: "2", title: "Card 2", value: 2),
      TestCard(id: "3", title: "Card 3", value: 3),
      TestCard(id: "4", title: "Card 4", value: 4),
      TestCard(id: "5", title: "Card 5", value: 5)
    ]
    
    sut = CardStackState<TestCard, LeftRight>()
  }
  
  override func tearDown() async throws {
    sut = nil
    testCards = nil
    try await super.tearDown()
  }
  
  // MARK: - Initialization Tests
  
  func test_init_withDefaultConfiguration_setsCorrectInitialState() {
    // Then
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.error)
    XCTAssertTrue(sut.cards.isEmpty)
    XCTAssertNil(sut.currentCard)
    XCTAssertEqual(sut.remainingCards, 0)
    XCTAssertFalse(sut.canUndo)
    XCTAssertEqual(sut.undoableCount, 0)
    XCTAssertTrue(sut.visibleCards.isEmpty)
  }
  
  func test_init_withCustomConfiguration_usesProvidedConfiguration() {
    // Given
    let config = CardStackConfiguration(
      maxVisibleCards: 3,
      swipeThreshold: 0.3,
      preloadThreshold: 2
    )
    
    // When
    sut = CardStackState(configuration: config)
    
    // Then
    XCTAssertTrue(sut.cards.isEmpty)
  }
  
  // MARK: - Card Management Tests
  
  func test_setCards_replacesAllExistingCards() async {
    // Given
    await sut.setCards(testCards)
    
    // When
    let newCards = [
      TestCard(id: "6", title: "New Card 1"),
      TestCard(id: "7", title: "New Card 2")
    ]
    await sut.setCards(newCards)
    
    // Then
    XCTAssertEqual(sut.cards.count, 2)
    XCTAssertEqual(sut.cards[0].id, "6")
    XCTAssertEqual(sut.cards[1].id, "7")
    XCTAssertEqual(sut.remainingCards, 2)
  }
  
  func test_appendCards_addsNewCardsToEnd() async {
    // Given
    await sut.setCards(Array(testCards.prefix(2)))
    
    // When
    sut.appendCards(Array(testCards.suffix(3)))
    
    // Then
    XCTAssertEqual(sut.cards.count, 5)
    XCTAssertEqual(sut.cards.last?.id, "5")
    XCTAssertEqual(sut.remainingCards, 5)
  }
  
  func test_appendCards_ignoresDuplicateIds() async {
    // Given
    await sut.setCards(testCards)
    
    // When
    let duplicateCards = [
      TestCard(id: "3", title: "Duplicate", value: 99),
      TestCard(id: "6", title: "New Card", value: 6)
    ]
    sut.appendCards(duplicateCards)
    
    // Then
    XCTAssertEqual(sut.cards.count, 6)
    XCTAssertEqual(sut.cards[2].value, 3) // Original card unchanged
    XCTAssertEqual(sut.cards.last?.id, "6")
  }
  
  func test_updateCard_modifiesExistingCard() async {
    // Given
    await sut.setCards(testCards)
    
    // When
    let updatedCard = TestCard(id: "3", title: "Updated Card 3", value: 99)
    sut.updateCard(updatedCard)
    
    // Then
    XCTAssertEqual(sut.cards[2].title, "Updated Card 3")
    XCTAssertEqual(sut.cards[2].value, 99)
  }
  
  func test_removeCards_removesSpecifiedCards() async {
    // Given
    await sut.setCards(testCards)
    
    // When
    sut.removeCards(ids: ["2", "4"])
    
    // Then
    XCTAssertEqual(sut.cards.count, 3)
    XCTAssertEqual(sut.cards.map { $0.id }, ["1", "3", "5"])
  }
  
  func test_clearCards_removesAllCards() async {
    // Given
    await sut.setCards(testCards)
    
    // When
    await sut.clearCards()
    
    // Then
    XCTAssertTrue(sut.cards.isEmpty)
    XCTAssertNil(sut.currentCard)
    XCTAssertEqual(sut.remainingCards, 0)
  }
  
  // MARK: - Swipe Action Tests
  
  func test_swipe_movesToNextCard() async {
    // Given
    await sut.setCards(testCards)
    
    // When
    let swipedCard = await sut.swipe(direction: .left)
    
    // Then
    XCTAssertEqual(swipedCard?.id, "1")
    XCTAssertEqual(sut.currentCard?.id, "2")
    XCTAssertEqual(sut.remainingCards, 4)
  }
  
  func test_swipe_returnsNilWhenNoCardsRemaining() async {
    // Given
    await sut.setCards([testCards[0]])
    _ = await sut.swipe(direction: .right)
    
    // When
    let result = await sut.swipe(direction: .left)
    
    // Then
    XCTAssertNil(result)
    XCTAssertEqual(sut.remainingCards, 0)
  }
  
  func test_swipe_skipsOverMissingCards() async {
    // Given
    await sut.setCards(testCards)
    sut.removeCards(ids: ["2", "3"])
    
    // When
    let swipedCard = await sut.swipe(direction: .right)
    
    // Then
    XCTAssertEqual(swipedCard?.id, "1")
    XCTAssertEqual(sut.currentCard?.id, "4")
  }
  
  // MARK: - Undo Tests
  
  func test_undo_withUndoConfiguration_restoresPreviousCard() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 3)
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    
    // When
    let swipedCard = await sut.swipe(direction: .left)
    let undoneCard = await sut.undo()
    
    // Then
    XCTAssertEqual(swipedCard?.id, undoneCard?.id)
    XCTAssertEqual(sut.currentCard?.id, "1")
    XCTAssertEqual(sut.undoableCount, 0)
  }
  
  func test_undo_withoutUndoConfiguration_returnsNil() async {
    // Given
    await sut.setCards(testCards)
    _ = await sut.swipe(direction: .right)
    
    // When
    let result = await sut.undo()
    
    // Then
    XCTAssertNil(result)
  }
  
  func test_undo_respectsLimit() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 2)
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    
    // When
    _ = await sut.swipe(direction: .left)
    _ = await sut.swipe(direction: .right)
    _ = await sut.swipe(direction: .left)
    
    // Then
    XCTAssertEqual(sut.undoableCount, 2)
    XCTAssertTrue(sut.canUndo)
  }
  
  func test_undo_withValidation_respectsValidator() async {
    // Given
    var shouldAllowUndo = true
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      limit: 5,
      onUndoValidation: { _ in shouldAllowUndo }
    )
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    
    // When
    _ = await sut.swipe(direction: .left)
    shouldAllowUndo = false
    let result = await sut.undo()
    
    // Then
    XCTAssertNil(result)
    XCTAssertEqual(sut.currentCard?.id, "2")
  }
  
  // MARK: - Tombstone Management Tests
  
  func test_tombstones_evictionCallback() async {
    // Given
    var evictedCards: [(TestCard, LeftRight)] = []
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      limit: 2,
      onEviction: { card, direction in
        evictedCards.append((card, direction))
      }
    )
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    
    // When
    _ = await sut.swipe(direction: .left)
    _ = await sut.swipe(direction: .right)
    _ = await sut.swipe(direction: .left) // Should evict first card
    
    // Then
    XCTAssertEqual(evictedCards.count, 1)
    XCTAssertEqual(evictedCards[0].0.id, "1")
    XCTAssertEqual(evictedCards[0].1, .left)
  }
  
  func test_clearTombstones_evictsAllTombstones() async {
    // Given
    var evictedCount = 0
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      limit: 5,
      onEviction: { _, _ in evictedCount += 1 }
    )
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    
    _ = await sut.swipe(direction: .left)
    _ = await sut.swipe(direction: .right)
    
    // When
    await sut.clearTombstones()
    
    // Then
    XCTAssertEqual(evictedCount, 2)
    XCTAssertEqual(sut.tombstoneCount, 0)
    XCTAssertFalse(sut.canUndo)
  }
  
  // MARK: - Collection Replacement Strategy Tests
  
  func test_replacementStrategy_clearTombstones() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      replacementStrategy: .clearTombstones
    )
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    _ = await sut.swipe(direction: .left)
    
    // When
    let newCards = [TestCard(id: "10", title: "New")]
    await sut.setCards(newCards)
    
    // Then
    XCTAssertEqual(sut.tombstoneCount, 0)
    XCTAssertFalse(sut.canUndo)
  }
  
  func test_replacementStrategy_preserveValidTombstones() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      replacementStrategy: .preserveValidTombstones
    )
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    
    _ = await sut.swipe(direction: .left) // Swipe card 1
    _ = await sut.swipe(direction: .right) // Swipe card 2
    
    // When
    let newCards = [
      TestCard(id: "1", title: "Card 1"), // Include card 1
      TestCard(id: "10", title: "New")
    ]
    await sut.setCards(newCards)
    
    // Then
    XCTAssertEqual(sut.tombstoneCount, 1) // Only card 1 preserved
    XCTAssertTrue(sut.isInTombstones("1"))
    XCTAssertFalse(sut.isInTombstones("2"))
  }
  
  func test_replacementStrategy_blockIfTombstones() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      replacementStrategy: .blockIfTombstones
    )
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    _ = await sut.swipe(direction: .left)
    
    // When
    let newCards = [TestCard(id: "10", title: "New")]
    await sut.setCards(newCards)
    
    // Then
    XCTAssertEqual(sut.cards.count, 5) // Original cards unchanged
    XCTAssertEqual(sut.cards[0].id, "1")
  }
  
  func test_replacementStrategy_askUser() async {
    // Given
    var confirmationRequested = false
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      replacementStrategy: .askUser,
      onConfirmReplacement: {
        confirmationRequested = true
        return false // Don't allow replacement
      }
    )
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    _ = await sut.swipe(direction: .left)
    
    // When
    let newCards = [TestCard(id: "10", title: "New")]
    await sut.setCards(newCards)
    
    // Then
    XCTAssertTrue(confirmationRequested)
    XCTAssertEqual(sut.cards.count, 5) // Original cards unchanged
  }
  
  // MARK: - State Management Tests
  
  func test_setLoading_updatesLoadingState() {
    // When
    sut.setLoading(true)
    
    // Then
    XCTAssertTrue(sut.isLoading)
    XCTAssertNil(sut.error)
    
    // When
    sut.setLoading(false)
    
    // Then
    XCTAssertFalse(sut.isLoading)
  }
  
  func test_setError_updatesErrorState() {
    // Given
    enum TestError: Error {
      case testError
    }
    
    // When
    sut.setError(TestError.testError)
    
    // Then
    XCTAssertNotNil(sut.error)
    XCTAssertFalse(sut.isLoading)
  }
  
  // MARK: - Index Management Tests
  
  func test_indexInStack_returnsCorrectIndex() async {
    // Given
    let config = CardStackConfiguration(maxVisibleCards: 3)
    sut = CardStackState(configuration: config)
    await sut.setCards(testCards)
    
    // Then
    XCTAssertEqual(sut.indexInStack(for: "1"), 0)
    XCTAssertEqual(sut.indexInStack(for: "2"), 1)
    XCTAssertEqual(sut.indexInStack(for: "3"), 2)
    XCTAssertNil(sut.indexInStack(for: "4")) // Beyond visible range
  }
  
  func test_shouldPreloadMore_triggersAtThreshold() async {
    // Given
    let config = CardStackConfiguration(preloadThreshold: 2)
    sut = CardStackState(configuration: config)
    await sut.setCards(testCards)
    
    // Initially should not preload
    XCTAssertFalse(sut.shouldPreloadMore)
    
    // When
    _ = await sut.swipe(direction: .left)
    _ = await sut.swipe(direction: .right)
    _ = await sut.swipe(direction: .left)
    
    // Then
    XCTAssertTrue(sut.shouldPreloadMore)
  }
  
  // MARK: - Visible Cards Tests
  
  func test_visibleCards_respectsMaxVisibleCards() async {
    // Given
    let config = CardStackConfiguration(maxVisibleCards: 3)
    sut = CardStackState(configuration: config)
    await sut.setCards(testCards)
    
    // Then
    XCTAssertEqual(sut.visibleCards.count, 3)
    XCTAssertEqual(sut.visibleCards.map { $0.id }, ["1", "2", "3"])
  }
  
  func test_visibleCards_updatesAfterSwipe() async {
    // Given
    let config = CardStackConfiguration(maxVisibleCards: 3)
    sut = CardStackState(configuration: config)
    await sut.setCards(testCards)
    
    // When
    _ = await sut.swipe(direction: .left)
    
    // Then
    XCTAssertEqual(sut.visibleCards.count, 3)
    XCTAssertEqual(sut.visibleCards.map { $0.id }, ["2", "3", "4"])
  }
  
  // MARK: - Swipe History Tests
  
  func test_swipeHistory_tracksSwipedCards() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 5)
    sut = CardStackState(undoConfiguration: undoConfig)
    await sut.setCards(testCards)
    
    // When
    _ = await sut.swipe(direction: .left)
    _ = await sut.swipe(direction: .right)
    
    // Then
    XCTAssertEqual(sut.swipeHistory.count, 2)
    XCTAssertEqual(sut.swipeHistory[0].card.id, "1")
    XCTAssertEqual(sut.swipeHistory[0].direction, .left)
    XCTAssertEqual(sut.swipeHistory[1].card.id, "2")
    XCTAssertEqual(sut.swipeHistory[1].direction, .right)
  }
  
  // MARK: - Edge Cases
  
  func test_swipe_withEmptyCards_returnsNil() async {
    // When
    let result = await sut.swipe(direction: .left)
    
    // Then
    XCTAssertNil(result)
  }
  
  func test_undo_withEmptyTombstones_returnsNil() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>()
    sut = CardStackState(undoConfiguration: undoConfig)
    
    // When
    let result = await sut.undo()
    
    // Then
    XCTAssertNil(result)
  }
  
  func test_removeCards_adjustsCurrentPosition() async {
    // Given
    await sut.setCards(testCards)
    
    // When
    sut.removeCards(ids: ["1", "2"])
    
    // Then
    XCTAssertEqual(sut.currentCard?.id, "3")
  }
}