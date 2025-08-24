//
//  IntegrationTests.swift
//  AsyncCardStackTests
//
//  Created by Test Engineer on 2025-08-23.
//

import XCTest
import SwiftUI
@testable import AsyncCardStack

// MARK: - Integration Test Card

struct IntegrationTestCard: CardElement, Codable, Equatable {
  let id: String
  let title: String
  let description: String
  let priority: Int
  
  init(id: String = UUID().uuidString, title: String, description: String = "", priority: Int = 0) {
    self.id = id
    self.title = title
    self.description = description
    self.priority = priority
  }
}

// MARK: - Custom Data Source for Integration Tests

@MainActor
final class IntegrationTestDataSource: CardDataSource {
  typealias Element = IntegrationTestCard
  
  private var cards: [IntegrationTestCard]
  private var loadMoreCallCount = 0
  private var swipeHistory: [(card: IntegrationTestCard, direction: String)] = []
  private var undoHistory: [IntegrationTestCard] = []
  
  init(initialCards: [IntegrationTestCard]) {
    self.cards = initialCards
  }
  
  func loadInitialCards() async throws -> [IntegrationTestCard] {
    // Simulate network delay
    try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
    return cards
  }
  
  func loadMoreCards() async throws -> [IntegrationTestCard] {
    loadMoreCallCount += 1
    
    // Simulate network delay
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    // Return new cards based on call count
    let newCards = (1...3).map { index in
      let id = "load\(loadMoreCallCount)_\(index)"
      return IntegrationTestCard(
        id: id,
        title: "Loaded Card \(loadMoreCallCount)-\(index)",
        priority: loadMoreCallCount
      )
    }
    
    return newCards
  }
  
  func reportSwipe(card: IntegrationTestCard, direction: any SwipeDirection) async throws {
    swipeHistory.append((card: card, direction: String(describing: direction)))
  }
  
  func reportUndo(card: IntegrationTestCard) async throws {
    undoHistory.append(card)
  }
  
  var cardStream: AsyncStream<CardUpdate<IntegrationTestCard>> {
    get async throws {
      AsyncStream { continuation in
        // Send initial cards
        continuation.yield(.initial(cards))
        
        // Simulate real-time updates
        Task {
          try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
          
          // Add a new card
          let newCard = IntegrationTestCard(
            id: "stream_1",
            title: "Streamed Card",
            description: "Added via stream",
            priority: 10
          )
          continuation.yield(.append([newCard]))
          
          // Update an existing card
          if !cards.isEmpty {
            var updatedCard = cards[0]
            updatedCard = IntegrationTestCard(
              id: updatedCard.id,
              title: updatedCard.title + " (Updated)",
              description: "Updated via stream",
              priority: updatedCard.priority + 1
            )
            continuation.yield(.update(updatedCard))
          }
          
          // Keep stream open for testing
        }
      }
    }
  }
  
  // Test helpers
  var swipeCount: Int { swipeHistory.count }
  var undoCount: Int { undoHistory.count }
  var lastSwipedCard: IntegrationTestCard? { swipeHistory.last?.card }
  var lastSwipeDirection: String? { swipeHistory.last?.direction }
}

// MARK: - Integration Tests

@MainActor
final class IntegrationTests: XCTestCase {
  
  // MARK: - Properties
  
  private var testCards: [IntegrationTestCard]!
  
  // MARK: - Setup & Teardown
  
  override func setUp() async throws {
    try await super.setUp()
    
    testCards = [
      IntegrationTestCard(id: "1", title: "First Card", description: "High priority", priority: 1),
      IntegrationTestCard(id: "2", title: "Second Card", description: "Medium priority", priority: 2),
      IntegrationTestCard(id: "3", title: "Third Card", description: "Low priority", priority: 3),
      IntegrationTestCard(id: "4", title: "Fourth Card", description: "Very low priority", priority: 4),
      IntegrationTestCard(id: "5", title: "Fifth Card", description: "Lowest priority", priority: 5)
    ]
  }
  
  override func tearDown() async throws {
    testCards = nil
    try await super.tearDown()
  }
  
  // MARK: - End-to-End Tests
  
  func test_fullSwipeFlow_withUndoAndReload() async throws {
    // Given
    let dataSource = IntegrationTestDataSource(initialCards: testCards)
    let undoConfig = UndoConfiguration<IntegrationTestCard, LeftRight>(
      limit: 3,
      onEviction: { card, direction in
        print("Evicted: \(card.title) - \(direction)")
      }
    )
    
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
      dataSource: dataSource,
      configuration: .default,
      undoConfiguration: undoConfig
    )
    
    // Start listening
    viewModel.startListening()
    
    // Wait for initial load and stream update
    try await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
    
    // Then - Initial state (includes stream update)
    XCTAssertEqual(viewModel.state.cards.count, 6) // 5 initial + 1 from stream
    XCTAssertEqual(viewModel.state.currentCard?.id, "1")
    
    // When - Swipe first card left
    await viewModel.swipe(direction: LeftRight.left)
    
    // Then - Card moved
    XCTAssertEqual(viewModel.state.currentCard?.id, "2")
    XCTAssertEqual(dataSource.swipeCount, 1)
    XCTAssertEqual(dataSource.lastSwipeDirection, "left")
    
    // When - Swipe second card right
    await viewModel.swipe(direction: LeftRight.right)
    
    // Then
    XCTAssertEqual(viewModel.state.currentCard?.id, "3")
    XCTAssertEqual(dataSource.swipeCount, 2)
    
    // When - Undo last swipe
    await viewModel.undo()
    
    // Then - Back to second card
    XCTAssertEqual(viewModel.state.currentCard?.id, "2")
    XCTAssertEqual(dataSource.undoCount, 1)
    
    // When - Undo again
    await viewModel.undo()
    
    // Then - Back to first card
    XCTAssertEqual(viewModel.state.currentCard?.id, "1")
    XCTAssertEqual(dataSource.undoCount, 2)
    
    // Verify stream updates were applied
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertTrue(viewModel.state.cards.count > 5) // Stream added cards
  }
  
  func test_preloadingBehavior_triggersAtThreshold() async throws {
    // Given
    let dataSource = IntegrationTestDataSource(initialCards: testCards)
    let config = CardStackConfiguration(
      maxVisibleCards: 3,
      preloadThreshold: 2
    )
    
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
      dataSource: dataSource,
      configuration: config
    )
    
    // Start listening
    viewModel.startListening()
    try await Task.sleep(nanoseconds: 150_000_000)
    
    // Initial card count
    let initialCount = viewModel.state.cards.count
    
    // When - Swipe until preload threshold (need to get down to 2 or fewer remaining)
    // We have 6 cards initially, need to swipe 4 to trigger preload
    await viewModel.swipe(direction: LeftRight.left)
    await viewModel.swipe(direction: LeftRight.left)
    await viewModel.swipe(direction: LeftRight.left)
    await viewModel.swipe(direction: LeftRight.left)
    
    // Wait for preload
    try await Task.sleep(nanoseconds: 200_000_000)
    
    // Then - More cards loaded
    XCTAssertGreaterThan(viewModel.state.cards.count, initialCount)
  }
  
  func test_concurrentOperations_maintainConsistency() async throws {
    // Given
    let dataSource = IntegrationTestDataSource(initialCards: testCards)
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
      dataSource: dataSource
    )
    
    viewModel.startListening()
    try await Task.sleep(nanoseconds: 150_000_000)
    
    // When - Perform concurrent operations
    await withTaskGroup(of: Void.self) { group in
      // Swipe operations
      group.addTask {
        await viewModel.swipe(direction: LeftRight.left)
      }
      
      group.addTask {
        try? await Task.sleep(nanoseconds: 10_000_000)
        await viewModel.swipe(direction: LeftRight.right)
      }
      
      // Load more operation
      group.addTask {
        try? await Task.sleep(nanoseconds: 20_000_000)
        await viewModel.loadMoreCards()
      }
    }
    
    // Then - State should be consistent
    XCTAssertNotNil(viewModel.state.currentCard)
    XCTAssertEqual(dataSource.swipeCount, 2)
    XCTAssertGreaterThan(viewModel.state.cards.count, 0)
  }
  
  func test_staticDataSource_integration() async throws {
    // Given - Specify Direction type parameter
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, StaticCardDataSource<IntegrationTestCard>>(
      cards: testCards,
      configuration: .default
    )
    
    // Start listening
    viewModel.startListening()
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then
    XCTAssertEqual(viewModel.state.cards.count, 5)
    XCTAssertEqual(viewModel.state.currentCard?.id, "1")
    
    // When - Swipe
    await viewModel.swipe(direction: LeftRight.left)
    
    // Then
    XCTAssertEqual(viewModel.state.currentCard?.id, "2")
  }
  
  func test_asyncSequenceDataSource_integration() async throws {
    // Given
    let sequence = AsyncStream<[IntegrationTestCard]> { continuation in
      // Initial batch
      continuation.yield(Array(testCards.prefix(3)))
      
      Task {
        // Second batch after delay
        try? await Task.sleep(nanoseconds: 100_000_000)
        continuation.yield(Array(testCards.suffix(2)))
        
        // Final update
        try? await Task.sleep(nanoseconds: 100_000_000)
        let newCard = IntegrationTestCard(id: "6", title: "New Card")
        continuation.yield([newCard])
        
        continuation.finish()
      }
    }
    
    // Specify Direction type parameter
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, AsyncSequenceDataSource<IntegrationTestCard, AsyncStream<[IntegrationTestCard]>>>(
      cardSequence: sequence
    )
    
    // Start listening
    viewModel.startListening()
    
    // Wait for initial batch
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(viewModel.state.cards.count, 3)
    
    // Wait for second batch
    try await Task.sleep(nanoseconds: 150_000_000)
    XCTAssertEqual(viewModel.state.cards.count, 1) // Replaced with single card
    
    // Wait for final update
    try await Task.sleep(nanoseconds: 150_000_000)
    XCTAssertEqual(viewModel.state.cards.count, 1)
    XCTAssertEqual(viewModel.state.currentCard?.id, "6")
  }
  
  func test_errorHandling_recoversGracefully() async throws {
    // Given
    let dataSource = IntegrationTestDataSource(initialCards: [])
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
      dataSource: dataSource
    )
    
    viewModel.startListening()
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // When - Try to swipe with no cards
    await viewModel.swipe(direction: LeftRight.left)
    
    // Then - Should handle gracefully
    XCTAssertNil(viewModel.state.currentCard)
    XCTAssertNil(viewModel.state.error)
    
    // When - Load more cards
    await viewModel.loadMoreCards()
    try await Task.sleep(nanoseconds: 50_000_000)
    
    // Then - Should have new cards
    XCTAssertGreaterThan(viewModel.state.cards.count, 0)
  }
  
  func test_memoryManagement_cleansUpProperly() async throws {
    // Given
    weak var weakViewModel: CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>?
    weak var weakDataSource: IntegrationTestDataSource?
    
    // Create in autoreleasepool to ensure cleanup
    await withCheckedContinuation { continuation in
      autoreleasepool {
        let dataSource = IntegrationTestDataSource(initialCards: testCards)
        let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
          dataSource: dataSource
        )
        
        weakDataSource = dataSource
        weakViewModel = viewModel
        
        viewModel.startListening()
        
        Task {
          try? await Task.sleep(nanoseconds: 100_000_000)
          
          // Stop listening before deallocation
          viewModel.stopListening()
          
          continuation.resume()
        }
      }
    }
    
    // Force cleanup
    try await Task.sleep(nanoseconds: 100_000_000)
    
    // Then - Should be deallocated
    XCTAssertNil(weakViewModel)
    XCTAssertNil(weakDataSource)
  }
  
  func test_undoConfiguration_replacementStrategies() async throws {
    // Test each replacement strategy
    let strategies: [CollectionReplacementStrategy] = [
      .clearTombstones,
      .preserveValidTombstones,
      .blockIfTombstones
    ]
    
    for strategy in strategies {
      // Given
      let dataSource = IntegrationTestDataSource(initialCards: testCards)
      let undoConfig = UndoConfiguration<IntegrationTestCard, LeftRight>(
        limit: 3,
        replacementStrategy: strategy
      )
      
      let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
        dataSource: dataSource,
        undoConfiguration: undoConfig
      )
      
      viewModel.startListening()
      try await Task.sleep(nanoseconds: 150_000_000)
      
      // When - Swipe and create tombstones
      await viewModel.swipe(direction: LeftRight.left)
      await viewModel.swipe(direction: LeftRight.right)
      
      // Try to replace cards
      let newCards = [
        IntegrationTestCard(id: "new1", title: "New Card 1"),
        IntegrationTestCard(id: "new2", title: "New Card 2")
      ]
      
      await viewModel.state.setCards(newCards)
      
      // Then - Verify strategy behavior
      switch strategy {
      case .clearTombstones:
        XCTAssertEqual(viewModel.state.tombstoneCount, 0)
        XCTAssertEqual(viewModel.state.cards.count, 2)
        
      case .preserveValidTombstones:
        // Tombstones should be cleared since new cards don't include old IDs
        XCTAssertEqual(viewModel.state.tombstoneCount, 0)
        
      case .blockIfTombstones:
        // Should keep original cards (replacement blocked)
        XCTAssertEqual(viewModel.state.currentCard?.id, "3") // After 2 swipes
        
      default:
        break
      }
    }
  }
  
  func test_visibleCards_respectsConfiguration() async throws {
    // Given
    let dataSource = IntegrationTestDataSource(initialCards: testCards)
    let config = CardStackConfiguration(
      maxVisibleCards: 2,
      swipeThreshold: 0.25,
      preloadThreshold: 1
    )
    
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
      dataSource: dataSource,
      configuration: config
    )
    
    viewModel.startListening()
    try await Task.sleep(nanoseconds: 150_000_000)
    
    // Then - Only 2 cards visible
    XCTAssertEqual(viewModel.state.visibleCards.count, 2)
    XCTAssertEqual(viewModel.state.visibleCards[0].id, "1")
    XCTAssertEqual(viewModel.state.visibleCards[1].id, "2")
    
    // When - Swipe
    await viewModel.swipe(direction: LeftRight.left)
    
    // Then - Next 2 cards visible
    XCTAssertEqual(viewModel.state.visibleCards.count, 2)
    XCTAssertEqual(viewModel.state.visibleCards[0].id, "2")
    XCTAssertEqual(viewModel.state.visibleCards[1].id, "3")
  }
  
  func test_swipeHistory_tracking() async throws {
    // Given
    let dataSource = IntegrationTestDataSource(initialCards: testCards)
    let undoConfig = UndoConfiguration<IntegrationTestCard, LeftRight>(limit: 10)
    
    let viewModel = CardStackViewModel<IntegrationTestCard, LeftRight, IntegrationTestDataSource>(
      dataSource: dataSource,
      undoConfiguration: undoConfig
    )
    
    viewModel.startListening()
    try await Task.sleep(nanoseconds: 150_000_000)
    
    // When - Perform various swipes
    await viewModel.swipe(direction: LeftRight.left)
    await viewModel.swipe(direction: LeftRight.right)
    await viewModel.swipe(direction: LeftRight.left)
    
    // Then - History tracked
    XCTAssertEqual(viewModel.state.swipeHistory.count, 3)
    XCTAssertEqual(viewModel.state.swipeHistory[0].direction, LeftRight.left)
    XCTAssertEqual(viewModel.state.swipeHistory[1].direction, LeftRight.right)
    XCTAssertEqual(viewModel.state.swipeHistory[2].direction, LeftRight.left)
    
    // When - Undo
    await viewModel.undo()
    
    // Then - History updated
    XCTAssertEqual(viewModel.state.swipeHistory.count, 2)
  }
}