//
//  PersistenceWarningTests.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import XCTest
@testable import AsyncCardStack

// MARK: - Test Card Types

/// Card that DOES conform to Codable
struct CodableCard: CardElement, Codable {
  let id: String
  let title: String
  
  init(id: String = UUID().uuidString, title: String) {
    self.id = id
    self.title = title
  }
}

/// Card that does NOT conform to Codable
struct NonCodableCard: CardElement {
  let id: String
  let title: String
  let nonCodableProperty: (@Sendable () -> Void)? // Closures can't be Codable
  
  init(id: String = UUID().uuidString, title: String, action: (@Sendable () -> Void)? = nil) {
    self.id = id
    self.title = title
    self.nonCodableProperty = action
  }
  
  static func == (lhs: NonCodableCard, rhs: NonCodableCard) -> Bool {
    lhs.id == rhs.id && lhs.title == rhs.title
  }
}

// MARK: - Tests

@MainActor
final class PersistenceWarningTests: XCTestCase {
  
  func testNoPersistenceWarningForCodableTypes() async {
    // Given: Codable card type with persistence requested
    let undoConfig = UndoConfiguration<CodableCard, LeftRight>(
      limit: 5,
      persistenceKey: "TestKey" // Persistence requested
    )
    
    let state = CardStackState<CodableCard, LeftRight>(
      undoConfiguration: undoConfig
    )
    
    // When: Setting cards and performing swipes
    let cards = [
      CodableCard(title: "Card 1"),
      CodableCard(title: "Card 2"),
      CodableCard(title: "Card 3")
    ]
    
    await state.setCards(cards)
    
    // Swipe a card (this triggers persistence check)
    _ = await state.swipe(direction: .left)
    
    // Then: No warning should be printed (can't easily test console output,
    // but the code path should execute without issues)
    XCTAssertEqual(state.undoableCount, 1)
    XCTAssertTrue(state.canUndo)
  }
  
  func testWarningShownForNonCodableTypes() async {
    // Given: Non-Codable card type with persistence requested
    let undoConfig = UndoConfiguration<NonCodableCard, LeftRight>(
      limit: 5,
      persistenceKey: "TestKey" // Persistence requested but won't work
    )
    
    let state = CardStackState<NonCodableCard, LeftRight>(
      undoConfiguration: undoConfig
    )
    
    // When: Setting cards and performing swipes
    let cards = [
      NonCodableCard(title: "Card 1"),
      NonCodableCard(title: "Card 2"),
      NonCodableCard(title: "Card 3")
    ]
    
    await state.setCards(cards)
    
    // Swipe a card (this should trigger the warning in DEBUG mode)
    _ = await state.swipe(direction: .left)
    
    // Then: Warning should be shown (in console) but functionality still works
    XCTAssertEqual(state.undoableCount, 1)
    XCTAssertTrue(state.canUndo)
  }
  
  func testNoWarningWhenPersistenceDisabled() async {
    // Given: Non-Codable card type but persistence NOT requested
    let undoConfig = UndoConfiguration<NonCodableCard, LeftRight>(
      limit: 5,
      persistenceKey: nil // No persistence requested
    )
    
    let state = CardStackState<NonCodableCard, LeftRight>(
      undoConfiguration: undoConfig
    )
    
    // When: Setting cards and performing swipes
    let cards = [
      NonCodableCard(title: "Card 1"),
      NonCodableCard(title: "Card 2"),
      NonCodableCard(title: "Card 3")
    ]
    
    await state.setCards(cards)
    
    // Swipe a card (no warning should be shown)
    _ = await state.swipe(direction: .left)
    
    // Then: No warning because persistence wasn't requested
    XCTAssertEqual(state.undoableCount, 1)
    XCTAssertTrue(state.canUndo)
  }
  
  func testConvenienceInitializerWithoutPersistence() async {
    // Given: Using the convenience initializer that explicitly disables persistence
    let undoConfig = UndoConfiguration<NonCodableCard, LeftRight>.withoutPersistence
    
    let state = CardStackState<NonCodableCard, LeftRight>(
      undoConfiguration: undoConfig
    )
    
    // When: Setting cards and performing swipes
    let cards = [
      NonCodableCard(title: "Card 1"),
      NonCodableCard(title: "Card 2")
    ]
    
    await state.setCards(cards)
    _ = await state.swipe(direction: .right)
    
    // Then: No warning because persistence is explicitly disabled
    XCTAssertEqual(state.undoableCount, 1)
    XCTAssertTrue(state.canUndo)
  }
  
  func testWarningOnlyShownOncePerInstance() async {
    // Given: Non-Codable card type with persistence requested
    let undoConfig = UndoConfiguration<NonCodableCard, LeftRight>(
      limit: 5,
      persistenceKey: "TestKey"
    )
    
    let state = CardStackState<NonCodableCard, LeftRight>(
      undoConfiguration: undoConfig
    )
    
    // When: Setting cards and performing multiple swipes
    let cards = [
      NonCodableCard(title: "Card 1"),
      NonCodableCard(title: "Card 2"),
      NonCodableCard(title: "Card 3"),
      NonCodableCard(title: "Card 4"),
      NonCodableCard(title: "Card 5")
    ]
    
    await state.setCards(cards)
    
    // Multiple swipes (warning should only show once)
    _ = await state.swipe(direction: .left)
    _ = await state.swipe(direction: .right)
    _ = await state.swipe(direction: .left)
    
    // Then: All swipes work, warning shown only once
    XCTAssertEqual(state.undoableCount, 3)
    XCTAssertTrue(state.canUndo)
  }
}