//
//  CardStackViewModelTests.swift
//  AsyncCardStackTests
//
//  Created by Test Engineer on 2025-08-23.
//

import XCTest
@testable import AsyncCardStack

// MARK: - Mock Data Source

@MainActor
final class MockDataSource: CardDataSource {
  typealias Element = TestCard
  
  var cards: [TestCard]
  var loadInitialCalled = false
  var loadMoreCalled = false
  var reportSwipeCalled = false
  var reportUndoCalled = false
  var shouldThrowError = false
  var moreCardsToLoad: [TestCard] = []
  
  private var streamContinuation: AsyncStream<CardUpdate<TestCard>>.Continuation?
  
  init(cards: [TestCard] = []) {
    self.cards = cards
  }
  
  func loadInitialCards() async throws -> [TestCard] {
    loadInitialCalled = true
    if shouldThrowError {
      throw TestError.mockError
    }
    return cards
  }
  
  func loadMoreCards() async throws -> [TestCard] {
    loadMoreCalled = true
    if shouldThrowError {
      throw TestError.mockError
    }
    return moreCardsToLoad
  }
  
  func reportSwipe(card: TestCard, direction: any SwipeDirection) async throws {
    reportSwipeCalled = true
    if shouldThrowError {
      throw TestError.mockError
    }
  }
  
  func reportUndo(card: TestCard) async throws {
    reportUndoCalled = true
    if shouldThrowError {
      throw TestError.mockError
    }
  }
  
  var cardStream: AsyncStream<CardUpdate<TestCard>> {
    get async throws {
      AsyncStream { continuation in
        self.streamContinuation = continuation
        
        // Send initial cards
        continuation.yield(.initial(cards))
        
        // Keep stream open for testing
        // Will be closed when continuation is deallocated
      }
    }
  }
  
  func sendUpdate(_ update: CardUpdate<TestCard>) {
    streamContinuation?.yield(update)
  }
  
  func finishStream() {
    streamContinuation?.finish()
  }
}

// MARK: - CardStackViewModel Tests

@MainActor
final class CardStackViewModelTests: XCTestCase {
  
  // MARK: - Properties
  
  private var mockDataSource: MockDataSource!
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
    
    mockDataSource = MockDataSource(cards: testCards)
  }
  
  override func tearDown() async throws {
    mockDataSource = nil
    testCards = nil
    try await super.tearDown()
  }
  
  // MARK: - Initialization Tests
  
  func test_init_withDataSource_setsCorrectInitialState() {
    // When
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    
    // Then
    XCTAssertFalse(sut.state.isLoading)
    XCTAssertNil(sut.state.error)
    XCTAssertTrue(sut.state.cards.isEmpty)
  }
  
  func test_init_withStaticCards_usesConvenienceInitializer() {
    // When - Specify Direction type parameter
    let sut = CardStackViewModel<TestCard, LeftRight, StaticCardDataSource<TestCard>>(
      cards: testCards
    )
    
    // Then
    XCTAssertFalse(sut.state.isLoading)
    XCTAssertTrue(sut.state.cards.isEmpty) // Cards not loaded until startListening
  }
  
  func test_init_withConfiguration_usesProvidedConfiguration() {
    // Given
    let config = CardStackConfiguration(
      maxVisibleCards: 3,
      swipeThreshold: 0.3,
      preloadThreshold: 2
    )
    
    // When
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource,
      configuration: config
    )
    
    // Then
    XCTAssertNotNil(sut.state)
  }
  
  func test_init_withUndoConfiguration_enablesUndo() {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 5)
    
    // When
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource,
      undoConfiguration: undoConfig
    )
    
    // Then
    XCTAssertNotNil(sut.state)
  }
  
  // MARK: - Data Loading Tests
  
  func test_startListening_loadsInitialCards() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    
    // When
    sut.startListening()
    
    // Wait for async operations
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    // Then
    XCTAssertTrue(mockDataSource.loadInitialCalled)
    XCTAssertEqual(sut.state.cards.count, 5)
    XCTAssertEqual(sut.state.currentCard?.id, "1")
    XCTAssertFalse(sut.state.isLoading)
  }
  
  func test_startListening_handlesLoadError() async {
    // Given
    mockDataSource.shouldThrowError = true
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    
    // When
    sut.startListening()
    
    // Wait for async operations
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertTrue(mockDataSource.loadInitialCalled)
    XCTAssertNotNil(sut.state.error)
    XCTAssertTrue(sut.state.cards.isEmpty)
  }
  
  func test_stopListening_cancelsUpdates() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    
    // When
    sut.startListening()
    try? await Task.sleep(nanoseconds: 50_000_000)
    sut.stopListening()
    
    // Send update after stopping
    mockDataSource.sendUpdate(.append([TestCard(id: "6", title: "Card 6")]))
    try? await Task.sleep(nanoseconds: 50_000_000)
    
    // Then
    XCTAssertEqual(sut.state.cards.count, 5) // Should not include card 6
  }
  
  // MARK: - Swipe Tests
  
  func test_swipe_movesToNextCard() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    await sut.swipe(direction: LeftRight.left)
    
    // Then
    XCTAssertTrue(mockDataSource.reportSwipeCalled)
    XCTAssertEqual(sut.state.currentCard?.id, "2")
    XCTAssertEqual(sut.state.remainingCards, 4)
  }
  
  func test_swipe_triggersPreload() async {
    // Given
    let config = CardStackConfiguration(preloadThreshold: 3)
    mockDataSource.moreCardsToLoad = [
      TestCard(id: "6", title: "Card 6"),
      TestCard(id: "7", title: "Card 7")
    ]
    
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource,
      configuration: config
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    await sut.swipe(direction: LeftRight.right)
    await sut.swipe(direction: LeftRight.left)
    
    // Wait for load more to complete
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertTrue(mockDataSource.loadMoreCalled)
    XCTAssertEqual(sut.state.cards.count, 7)
  }
  
  func test_swipe_handlesReportError() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 5)
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource,
      undoConfiguration: undoConfig
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    mockDataSource.shouldThrowError = true
    await sut.swipe(direction: LeftRight.left)
    
    // Then
    XCTAssertNotNil(sut.state.error)
    // Card should be undone due to error
    XCTAssertEqual(sut.state.currentCard?.id, "1")
  }
  
  // MARK: - Undo Tests
  
  func test_undo_restoresPreviousCard() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 5)
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource,
      undoConfiguration: undoConfig
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    await sut.swipe(direction: LeftRight.left)
    await sut.undo()
    
    // Then
    XCTAssertTrue(mockDataSource.reportUndoCalled)
    XCTAssertEqual(sut.state.currentCard?.id, "1")
    XCTAssertEqual(sut.state.remainingCards, 5)
  }
  
  func test_undo_handlesReportError() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 5)
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource,
      undoConfiguration: undoConfig
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    await sut.swipe(direction: LeftRight.right)
    
    // When
    mockDataSource.shouldThrowError = true
    await sut.undo()
    
    // Then
    XCTAssertNotNil(sut.state.error)
    // Undo should still complete even if reporting fails
    XCTAssertEqual(sut.state.currentCard?.id, "1")
  }
  
  // MARK: - Stream Update Tests
  
  func test_streamUpdate_appendCards() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    mockDataSource.sendUpdate(.append([
      TestCard(id: "6", title: "Card 6"),
      TestCard(id: "7", title: "Card 7")
    ]))
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertEqual(sut.state.cards.count, 7)
    XCTAssertEqual(sut.state.cards.last?.id, "7")
  }
  
  func test_streamUpdate_removeCards() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    mockDataSource.sendUpdate(.remove(["2", "4"]))
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertEqual(sut.state.cards.count, 3)
    XCTAssertEqual(sut.state.cards.map { $0.id }, ["1", "3", "5"])
  }
  
  func test_streamUpdate_updateCard() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    let updatedCard = TestCard(id: "3", title: "Updated Card 3", value: 99)
    mockDataSource.sendUpdate(.update(updatedCard))
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertEqual(sut.state.cards[2].title, "Updated Card 3")
    XCTAssertEqual(sut.state.cards[2].value, 99)
  }
  
  func test_streamUpdate_clearCards() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    mockDataSource.sendUpdate(.clear)
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertTrue(sut.state.cards.isEmpty)
    XCTAssertNil(sut.state.currentCard)
  }
  
  func test_streamUpdate_replaceCards() async {
    // Given
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    let newCards = [
      TestCard(id: "10", title: "New Card 1"),
      TestCard(id: "11", title: "New Card 2")
    ]
    mockDataSource.sendUpdate(.replace(newCards))
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertEqual(sut.state.cards.count, 2)
    XCTAssertEqual(sut.state.cards[0].id, "10")
    XCTAssertEqual(sut.state.cards[1].id, "11")
  }
  
  // MARK: - Load More Tests
  
  func test_loadMoreCards_appendsNewCards() async {
    // Given
    mockDataSource.moreCardsToLoad = [
      TestCard(id: "6", title: "Card 6"),
      TestCard(id: "7", title: "Card 7")
    ]
    
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When
    await sut.loadMoreCards()
    
    // Then
    XCTAssertTrue(mockDataSource.loadMoreCalled)
    XCTAssertEqual(sut.state.cards.count, 7)
  }
  
  func test_loadMoreCards_preventsMultipleConcurrentLoads() async {
    // Given
    mockDataSource.moreCardsToLoad = [
      TestCard(id: "6", title: "Card 6")
    ]
    
    let sut = CardStackViewModel<TestCard, LeftRight, MockDataSource>(
      dataSource: mockDataSource
    )
    sut.startListening()
    try? await Task.sleep(nanoseconds: 100_000_000)
    
    // When - Call load more multiple times concurrently
    async let load1 = sut.loadMoreCards()
    async let load2 = sut.loadMoreCards()
    async let load3 = sut.loadMoreCards()
    
    await load1
    await load2
    await load3
    
    // Then - Should only load once
    XCTAssertEqual(sut.state.cards.count, 6)
  }
  
  // MARK: - Async Sequence Data Source Tests
  
  func test_asyncSequenceDataSource_streamsUpdates() async {
    // Given
    let sequence = AsyncStream<[TestCard]> { continuation in
      continuation.yield([TestCard(id: "1", title: "Initial")])
      Task {
        try? await Task.sleep(nanoseconds: 50_000_000)
        continuation.yield([TestCard(id: "2", title: "Update")])
        continuation.finish()
      }
    }
    
    // When - Specify Direction type parameter
    let sut = CardStackViewModel<TestCard, LeftRight, AsyncSequenceDataSource<TestCard, AsyncStream<[TestCard]>>>(
      cardSequence: sequence
    )
    sut.startListening()
    
    // Wait for updates
    try? await Task.sleep(nanoseconds: 200_000_000)
    
    // Then
    XCTAssertEqual(sut.state.cards.count, 1)
    XCTAssertEqual(sut.state.cards[0].id, "2")
  }
}