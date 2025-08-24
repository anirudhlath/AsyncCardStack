//
//  SwipeRemovalTests.swift
//  AsyncCardStackTests
//
//  Created by Feature Developer on 8/23/25.
//
//  Tests to verify that cards are properly removed from UI after swipe

import XCTest
@testable import AsyncCardStack

final class SwipeRemovalTests: XCTestCase {
  
  // MARK: - Test Types
  
  struct TestCard: CardElement {
    let id: String
    let name: String
  }
  
  // MARK: - Tests
  
  @MainActor
  func testCardRemovedFromUIAfterSwipe() async throws {
    // Arrange
    let cards = [
      TestCard(id: "1", name: "Card 1"),
      TestCard(id: "2", name: "Card 2"),
      TestCard(id: "3", name: "Card 3")
    ]
    
    let dataSource = StaticCardDataSource(cards: cards)
    let viewModel = CardStackViewModel<TestCard, LeftRight, StaticCardDataSource<TestCard>>(
      dataSource: dataSource,
      configuration: .default
    )
    
    // Start listening to load initial cards
    viewModel.startListening()
    
    // Wait for cards to load
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    // Act - Verify initial state
    XCTAssertEqual(viewModel.state.visibleCards.count, 3)
    XCTAssertEqual(viewModel.state.currentCard?.id, "1")
    
    // Swipe the first card
    await viewModel.swipe(direction: .right)
    
    // Assert - Card should be removed from visible cards
    XCTAssertEqual(viewModel.state.visibleCards.count, 2)
    XCTAssertEqual(viewModel.state.currentCard?.id, "2")
    XCTAssertFalse(viewModel.state.visibleCards.contains { $0.id == "1" })
    
    // Swipe the second card
    await viewModel.swipe(direction: .left)
    
    // Assert - Second card should be removed
    XCTAssertEqual(viewModel.state.visibleCards.count, 1)
    XCTAssertEqual(viewModel.state.currentCard?.id, "3")
    XCTAssertFalse(viewModel.state.visibleCards.contains { $0.id == "2" })
  }
  
  @MainActor
  func testCardRemovedWhenFirestoreSendsRemoveUpdate() async throws {
    // Arrange
    let initialCards = [
      TestCard(id: "1", name: "Card 1"),
      TestCard(id: "2", name: "Card 2"),
      TestCard(id: "3", name: "Card 3")
    ]
    
    // Create a stream that we can control
    let stream = AsyncStream<CardUpdate<TestCard>> { continuation in
      // Send initial cards
      continuation.yield(.initial(initialCards))
      
      // Simulate Firestore removing a card after swipe
      Task {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        continuation.yield(.remove(Set(["1"])))
      }
    }
    
    let dataSource = AsyncStreamDataSource(stream: stream)
    let viewModel = CardStackViewModel<TestCard, LeftRight, AsyncStreamDataSource<TestCard>>(
      dataSource: dataSource,
      configuration: .default
    )
    
    // Act
    viewModel.startListening()
    
    // Wait for initial cards to load
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    // Verify initial state
    XCTAssertEqual(viewModel.state.visibleCards.count, 3)
    XCTAssertTrue(viewModel.state.visibleCards.contains { $0.id == "1" })
    
    // Wait for remove update
    try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
    
    // Assert - Card should be removed from visible cards
    XCTAssertEqual(viewModel.state.visibleCards.count, 2)
    XCTAssertFalse(viewModel.state.visibleCards.contains { $0.id == "1" })
    XCTAssertEqual(viewModel.state.currentCard?.id, "2")
  }
  
  @MainActor
  func testReplaceUpdateCorrectlyUpdatesVisibleCards() async throws {
    // Arrange
    let initialCards = [
      TestCard(id: "1", name: "Card 1"),
      TestCard(id: "2", name: "Card 2"),
      TestCard(id: "3", name: "Card 3")
    ]
    
    let updatedCards = [
      TestCard(id: "2", name: "Card 2"),
      TestCard(id: "3", name: "Card 3"),
      TestCard(id: "4", name: "Card 4")
    ]
    
    // Create a stream that we can control
    let stream = AsyncStream<CardUpdate<TestCard>> { continuation in
      // Send initial cards
      continuation.yield(.initial(initialCards))
      
      // Simulate Firestore sending a replace update after a swipe
      Task {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        continuation.yield(.replace(updatedCards))
      }
    }
    
    let dataSource = AsyncStreamDataSource(stream: stream)
    let viewModel = CardStackViewModel<TestCard, LeftRight, AsyncStreamDataSource<TestCard>>(
      dataSource: dataSource,
      configuration: .default
    )
    
    // Act
    viewModel.startListening()
    
    // Wait for initial cards to load
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    
    // Verify initial state
    XCTAssertEqual(viewModel.state.visibleCards.count, 3)
    XCTAssertEqual(viewModel.state.currentCard?.id, "1")
    
    // Wait for replace update
    try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
    
    // Assert - Visible cards should be updated
    XCTAssertEqual(viewModel.state.visibleCards.count, 3)
    XCTAssertFalse(viewModel.state.visibleCards.contains { $0.id == "1" })
    XCTAssertTrue(viewModel.state.visibleCards.contains { $0.id == "2" })
    XCTAssertTrue(viewModel.state.visibleCards.contains { $0.id == "3" })
    XCTAssertTrue(viewModel.state.visibleCards.contains { $0.id == "4" })
    XCTAssertEqual(viewModel.state.currentCard?.id, "2")
  }
  
  @MainActor
  func testPositionAdjustsCorrectlyAfterRemoval() async throws {
    // Arrange
    let cards = [
      TestCard(id: "1", name: "Card 1"),
      TestCard(id: "2", name: "Card 2"),
      TestCard(id: "3", name: "Card 3")
    ]
    
    let state = CardStackState<TestCard, LeftRight>()
    await state.setCards(cards)
    
    // Act - Remove the first card (simulating Firebase removal)
    state.removeCards(ids: Set(["1"]))
    
    // Assert - Current card should now be Card 2
    XCTAssertEqual(state.currentCard?.id, "2")
    XCTAssertEqual(state.visibleCards.count, 2)
    
    // Remove the current card
    state.removeCards(ids: Set(["2"]))
    
    // Assert - Current card should now be Card 3
    XCTAssertEqual(state.currentCard?.id, "3")
    XCTAssertEqual(state.visibleCards.count, 1)
    
    // Remove the last card
    state.removeCards(ids: Set(["3"]))
    
    // Assert - No cards left
    XCTAssertNil(state.currentCard)
    XCTAssertEqual(state.visibleCards.count, 0)
  }
}