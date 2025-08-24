//
//  DataSourceTests.swift
//  AsyncCardStackTests
//
//  Created by Test Engineer on 2025-08-23.
//

import XCTest
@testable import AsyncCardStack

// MARK: - Test Error

enum TestError: Error {
  case mockError
}

// MARK: - DataSource Tests

@MainActor
final class DataSourceTests: XCTestCase {
  
  // MARK: - StaticCardDataSource Tests
  
  func test_staticDataSource_providesInitialCards() async throws {
    // Given
    let cards = [
      TestCard(id: "1", title: "Card 1"),
      TestCard(id: "2", title: "Card 2")
    ]
    let dataSource = StaticCardDataSource(cards: cards)
    
    // When
    let initialCards = try await dataSource.loadInitialCards()
    
    // Then
    XCTAssertEqual(initialCards.count, 2)
    XCTAssertEqual(initialCards[0].id, "1")
  }
  
  func test_staticDataSource_streamProvidesInitialAndFinishes() async throws {
    // Given
    let cards = [TestCard(id: "1", title: "Card 1")]
    let dataSource = StaticCardDataSource(cards: cards)
    
    // When
    var updates: [CardUpdate<TestCard>] = []
    for await update in try await dataSource.cardStream {
      updates.append(update)
    }
    
    // Then
    XCTAssertEqual(updates.count, 1)
    if case .initial(let receivedCards) = updates[0] {
      XCTAssertEqual(receivedCards.count, 1)
      XCTAssertEqual(receivedCards[0].id, "1")
    } else {
      XCTFail("Expected initial update")
    }
  }
  
  func test_staticDataSource_loadMoreReturnsEmpty() async throws {
    // Given
    let dataSource = StaticCardDataSource<TestCard>(cards: [])
    
    // When
    let moreCards = try await dataSource.loadMoreCards()
    
    // Then
    XCTAssertTrue(moreCards.isEmpty)
  }
  
  func test_staticDataSource_reportSwipeDoesNothing() async throws {
    // Given
    let dataSource = StaticCardDataSource<TestCard>(cards: [])
    let card = TestCard(id: "1", title: "Card")
    
    // When/Then - should not throw
    try await dataSource.reportSwipe(card: card, direction: LeftRight.left)
  }
  
  func test_staticDataSource_reportUndoDoesNothing() async throws {
    // Given
    let dataSource = StaticCardDataSource<TestCard>(cards: [])
    let card = TestCard(id: "1", title: "Card")
    
    // When/Then - should not throw
    try await dataSource.reportUndo(card: card)
  }
  
  // MARK: - AsyncSequenceDataSource Tests
  
  func test_asyncSequenceDataSource_streamsUpdates() async throws {
    // Given
    let sequence = AsyncStream<[TestCard]> { continuation in
      continuation.yield([TestCard(id: "1", title: "Initial")])
      continuation.yield([TestCard(id: "2", title: "Update")])
      continuation.finish()
    }
    
    let dataSource = AsyncSequenceDataSource(sequence: sequence)
    
    // When
    var updates: [CardUpdate<TestCard>] = []
    for await update in try await dataSource.cardStream {
      updates.append(update)
    }
    
    // Then
    XCTAssertEqual(updates.count, 2)
    
    if case .initial(let cards) = updates[0] {
      XCTAssertEqual(cards[0].id, "1")
    } else {
      XCTFail("Expected initial update")
    }
    
    if case .replace(let cards) = updates[1] {
      XCTAssertEqual(cards[0].id, "2")
    } else {
      XCTFail("Expected replace update")
    }
  }
  
  func test_asyncSequenceDataSource_handlesError() async throws {
    // Given
    struct TestSequence: AsyncSequence {
      typealias Element = [TestCard]
      
      struct AsyncIterator: AsyncIteratorProtocol {
        var hasThrown = false
        
        mutating func next() async throws -> [TestCard]? {
          if !hasThrown {
            hasThrown = true
            throw TestError.mockError
          }
          return nil
        }
      }
      
      func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator()
      }
    }
    
    let sequence = TestSequence()
    let dataSource = AsyncSequenceDataSource(sequence: sequence)
    
    // When
    var updates: [CardUpdate<TestCard>] = []
    for await update in try await dataSource.cardStream {
      updates.append(update)
    }
    
    // Then - stream should finish after error
    XCTAssertTrue(updates.isEmpty)
  }
  
  // MARK: - AsyncStreamDataSource Tests
  
  func test_asyncStreamDataSource_bridgesStream() async throws {
    // Given
    var continuation: AsyncStream<CardUpdate<TestCard>>.Continuation?
    let stream = AsyncStream<CardUpdate<TestCard>> { cont in
      continuation = cont
    }
    
    actor ReportTracker {
      var swipeReported = false
      var undoReported = false
      
      func reportSwipe() { swipeReported = true }
      func reportUndo() { undoReported = true }
    }
    
    let tracker = ReportTracker()
    
    let dataSource = AsyncStreamDataSource(
      stream: stream,
      onSwipe: { _, _ in await tracker.reportSwipe() },
      onUndo: { _ in await tracker.reportUndo() },
      onLoadMore: { [TestCard(id: "more", title: "More")] }
    )
    
    // Test stream bridging
    continuation?.yield(.initial([TestCard(id: "1", title: "Card")]))
    
    var updates: [CardUpdate<TestCard>] = []
    let streamTask = Task {
      for await update in try await dataSource.cardStream {
        updates.append(update)
        if updates.count >= 1 {
          break
        }
      }
    }
    
    try? await Task.sleep(nanoseconds: 50_000_000)
    streamTask.cancel()
    
    XCTAssertEqual(updates.count, 1)
    
    // Test callbacks
    let card = TestCard(id: "1", title: "Card")
    try await dataSource.reportSwipe(card: card, direction: LeftRight.left)
    try await dataSource.reportUndo(card: card)
    let moreCards = try await dataSource.loadMoreCards()
    
    let swipeReported = await tracker.swipeReported
    let undoReported = await tracker.undoReported
    XCTAssertTrue(swipeReported)
    XCTAssertTrue(undoReported)
    XCTAssertEqual(moreCards.count, 1)
    
    continuation?.finish()
  }
  
  func test_asyncStreamDataSource_withoutHandlers() async throws {
    // Given
    let stream = AsyncStream<CardUpdate<TestCard>> { _ in }
    let dataSource = AsyncStreamDataSource(stream: stream)
    
    // When/Then - should not throw
    let card = TestCard(id: "1", title: "Card")
    try await dataSource.reportSwipe(card: card, direction: LeftRight.right)
    try await dataSource.reportUndo(card: card)
    let moreCards = try await dataSource.loadMoreCards()
    
    XCTAssertTrue(moreCards.isEmpty)
  }
  
  // MARK: - ContinuationDataSource Tests
  
  func test_continuationDataSource_manualControl() async throws {
    // Given
    let dataSource = ContinuationDataSource<TestCard>()
    
    // Setup stream listener
    var updates: [CardUpdate<TestCard>] = []
    let streamTask = Task {
      for await update in try await dataSource.cardStream {
        updates.append(update)
      }
    }
    
    // When - send various updates
    dataSource.sendInitialCards([TestCard(id: "1", title: "Initial")])
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    dataSource.appendCards([TestCard(id: "2", title: "Append")])
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    dataSource.replaceCards([TestCard(id: "3", title: "Replace")])
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    dataSource.updateCard(TestCard(id: "3", title: "Updated", value: 99))
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    dataSource.removeCards(ids: ["3"])
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    dataSource.clearCards()
    try? await Task.sleep(nanoseconds: 10_000_000)
    
    dataSource.finish()
    
    // Wait for stream to complete
    _ = try? await streamTask.value
    
    // Then
    XCTAssertEqual(updates.count, 6)
    
    if case .initial = updates[0] {} else { XCTFail("Expected initial") }
    if case .append = updates[1] {} else { XCTFail("Expected append") }
    if case .replace = updates[2] {} else { XCTFail("Expected replace") }
    if case .update = updates[3] {} else { XCTFail("Expected update") }
    if case .remove = updates[4] {} else { XCTFail("Expected remove") }
    if case .clear = updates[5] {} else { XCTFail("Expected clear") }
  }
  
  func test_continuationDataSource_loadMethods() async throws {
    // Given
    let dataSource = ContinuationDataSource<TestCard>()
    
    // When
    let initialCards = try await dataSource.loadInitialCards()
    let moreCards = try await dataSource.loadMoreCards()
    
    // Then
    XCTAssertTrue(initialCards.isEmpty)
    XCTAssertTrue(moreCards.isEmpty)
  }
  
  func test_continuationDataSource_reportMethods() async throws {
    // Given
    let dataSource = ContinuationDataSource<TestCard>()
    let card = TestCard(id: "1", title: "Card")
    
    // When/Then - should not throw
    try await dataSource.reportSwipe(card: card, direction: LeftRight.left)
    try await dataSource.reportUndo(card: card)
  }
  
  // MARK: - Concurrent Access Tests
  
  func test_dataSource_concurrentAccess() async throws {
    // Given
    let dataSource = ContinuationDataSource<TestCard>()
    
    // When - multiple concurrent operations
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        dataSource.sendInitialCards([TestCard(id: "1", title: "Card 1")])
      }
      
      group.addTask {
        dataSource.appendCards([TestCard(id: "2", title: "Card 2")])
      }
      
      group.addTask {
        dataSource.updateCard(TestCard(id: "1", title: "Updated"))
      }
      
      group.addTask {
        try? await dataSource.reportSwipe(
          card: TestCard(id: "1", title: "Card"),
          direction: LeftRight.left
        )
      }
    }
    
    // Then - should not crash
    dataSource.finish()
  }
  
  // MARK: - Memory Management Tests
  
  func test_dataSource_properCleanup() {
    // Given
    var dataSource: ContinuationDataSource<TestCard>? = ContinuationDataSource()
    weak var weakDataSource = dataSource
    
    // When
    dataSource?.finish()
    dataSource = nil
    
    // Then
    XCTAssertNil(weakDataSource)
  }
}