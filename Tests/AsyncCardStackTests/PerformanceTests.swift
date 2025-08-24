//
//  PerformanceTests.swift
//  AsyncCardStackTests
//
//  Created by Test Engineer on 2025-08-23.
//

import XCTest
@testable import AsyncCardStack

// MARK: - Performance Tests

@MainActor
final class PerformanceTests: XCTestCase {
  
  // MARK: - Large Dataset Tests
  
  func test_largeDataset_initialization() {
    measure {
      // Given
      let _ = (0..<10000).map { index in
        TestCard(id: "\(index)", title: "Card \(index)", value: index)
      }
      
      // When
      let _ = CardStackState<TestCard, LeftRight>()
    }
  }
  
  func test_largeDataset_setCards() async {
    // Given
    let sut = CardStackState<TestCard, LeftRight>()
    let cards = (0..<10000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    
    // When/Then
    await measureAsync {
      await sut.setCards(cards)
    }
  }
  
  func test_largeDataset_appendCards() async {
    // Given
    let sut = CardStackState<TestCard, LeftRight>()
    let initialCards = (0..<5000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    await sut.setCards(initialCards)
    
    let newCards = (5000..<10000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    
    // When/Then
    await measureAsync {
      sut.appendCards(newCards)
    }
  }
  
  func test_largeDataset_swipePerformance() async {
    // Given
    let sut = CardStackState<TestCard, LeftRight>()
    let cards = (0..<1000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    await sut.setCards(cards)
    
    // When/Then
    await measureAsync {
      for _ in 0..<100 {
        _ = await sut.swipe(direction: .left)
      }
    }
  }
  
  func test_largeDataset_visibleCardsComputation() async {
    // Given
    let config = CardStackConfiguration(maxVisibleCards: 5)
    let sut = CardStackState<TestCard, LeftRight>(configuration: config)
    let cards = (0..<10000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    await sut.setCards(cards)
    
    // When/Then
    measure {
      for _ in 0..<1000 {
        _ = sut.visibleCards
      }
    }
  }
  
  // MARK: - Undo Performance Tests
  
  func test_undoPerformance_withLargeHistory() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(limit: 100)
    let sut = CardStackState<TestCard, LeftRight>(undoConfiguration: undoConfig)
    let cards = (0..<200).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    await sut.setCards(cards)
    
    // Build up undo history
    for _ in 0..<100 {
      _ = await sut.swipe(direction: .left)
    }
    
    // When/Then
    await measureAsync {
      for _ in 0..<50 {
        _ = await sut.undo()
      }
    }
  }
  
  func test_tombstoneEviction_performance() async {
    // Given
    let undoConfig = UndoConfiguration<TestCard, LeftRight>(
      limit: 10,
      onEviction: { _, _ in 
        // Eviction callback
      }
    )
    let sut = CardStackState<TestCard, LeftRight>(undoConfiguration: undoConfig)
    let cards = (0..<1000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    await sut.setCards(cards)
    
    // When/Then
    await measureAsync {
      for _ in 0..<100 {
        _ = await sut.swipe(direction: .left)
      }
    }
  }
  
  // MARK: - Stream Performance Tests
  
  func test_streamUpdates_performance() async {
    // Given
    let dataSource = ContinuationDataSource<TestCard>()
    let viewModel = CardStackViewModel<TestCard, LeftRight, ContinuationDataSource<TestCard>>(dataSource: dataSource)
    
    viewModel.startListening()
    defer { viewModel.stopListening() }
    
    // When/Then
    await measureAsync {
      for i in 0..<100 {
        let cards = [TestCard(id: "\(i)", title: "Card \(i)")]
        dataSource.appendCards(cards)
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
      }
    }
  }
  
  func test_concurrentStreamUpdates_performance() async {
    // Given
    let dataSource = ContinuationDataSource<TestCard>()
    let viewModel = CardStackViewModel<TestCard, LeftRight, ContinuationDataSource<TestCard>>(dataSource: dataSource)
    
    viewModel.startListening()
    defer { viewModel.stopListening() }
    
    // When/Then
    await measureAsync {
      await withTaskGroup(of: Void.self) { group in
        for i in 0..<100 {
          group.addTask {
            let cards = [TestCard(id: "\(i)", title: "Card \(i)")]
            dataSource.appendCards(cards)
          }
        }
      }
    }
  }
  
  // MARK: - Memory Performance Tests
  
  func test_memoryUsage_largeCardContent() async {
    // Given
    struct LargeCard: CardElement, Equatable {
      let id: String
      let data: Data
      
      init(id: String) {
        self.id = id
        // Create 1MB of data per card
        self.data = Data(repeating: 0, count: 1024 * 1024)
      }
    }
    
    let sut = CardStackState<LargeCard, LeftRight>()
    
    // When
    let cards = (0..<100).map { LargeCard(id: "\($0)") }
    
    // Then - measure memory impact
    await measureAsync {
      await sut.setCards(cards)
      await sut.clearCards()
    }
  }
  
  func test_memoryLeak_viewModelLifecycle() {
    // Given
    var viewModels: [CardStackViewModel<TestCard, LeftRight, StaticCardDataSource<TestCard>>] = []
    
    // When/Then
    measure {
      for i in 0..<100 {
        let cards = [TestCard(id: "\(i)", title: "Card \(i)")]
        let viewModel = CardStackViewModel<TestCard, LeftRight, StaticCardDataSource<TestCard>>(cards: cards)
        viewModel.startListening()
        viewModels.append(viewModel)
      }
      
      // Clean up
      for viewModel in viewModels {
        viewModel.stopListening()
      }
      viewModels.removeAll()
    }
  }
  
  // MARK: - Index Management Performance
  
  func test_indexInStack_performance() async {
    // Given
    let config = CardStackConfiguration(maxVisibleCards: 5)
    let sut = CardStackState<TestCard, LeftRight>(configuration: config)
    let cards = (0..<10000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    await sut.setCards(cards)
    
    // When/Then
    measure {
      for i in 0..<1000 {
        _ = sut.indexInStack(for: "\(i)")
      }
    }
  }
  
  func test_removeCards_performance() async {
    // Given
    let sut = CardStackState<TestCard, LeftRight>()
    let cards = (0..<10000).map { index in
      TestCard(id: "\(index)", title: "Card \(index)", value: index)
    }
    await sut.setCards(cards)
    
    // When/Then
    await measureAsync {
      let idsToRemove = Set((0..<1000).map { "\($0)" })
      sut.removeCards(ids: idsToRemove)
    }
  }
  
  // MARK: - Helper Methods
  
  private func measureAsync(_ block: @escaping () async -> Void) async {
    let start = CFAbsoluteTimeGetCurrent()
    await block()
    let end = CFAbsoluteTimeGetCurrent()
    print("Execution time: \(end - start) seconds")
  }
}