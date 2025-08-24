//
//  CardStackProtocols.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import Foundation
import SwiftUI

// MARK: - Core Protocols

/// Protocol for card elements that can be displayed in the stack
public protocol CardElement: Identifiable, Equatable, Sendable where ID: Hashable & Sendable {
}

/// Protocol for defining swipe directions
public protocol SwipeDirection: Equatable, CaseIterable, Sendable {
  /// Create a direction from an angle
  static func from(angle: Angle) -> Self?
  
  /// The angle representing this direction
  var angle: Angle { get }
}

/// Protocol for data sources that provide cards
public protocol CardDataSource: Sendable {
  associatedtype Element: CardElement
  
  /// Stream of card updates
  var cardStream: AsyncStream<CardUpdate<Element>> { get async throws }
  
  /// Load initial cards
  func loadInitialCards() async throws -> [Element]
  
  /// Load more cards if available
  func loadMoreCards() async throws -> [Element]
  
  /// Report a swipe action
  func reportSwipe(card: Element, direction: any SwipeDirection) async throws
  
  /// Report an undo action
  func reportUndo(card: Element) async throws
}

// MARK: - Card Updates

/// Represents different types of updates to the card stack
public enum CardUpdate<Element: CardElement>: Sendable {
  case initial([Element])
  case append([Element])
  case replace([Element])
  case remove(Set<Element.ID>)
  case clear
  case update(Element)
}

// MARK: - Swipe Actions

/// Represents a swipe action on a card
public struct SwipeAction<Element: CardElement, Direction: SwipeDirection>: Sendable {
  public let card: Element
  public let direction: Direction
  public let timestamp: Date
  
  public init(card: Element, direction: Direction, timestamp: Date = Date()) {
    self.card = card
    self.direction = direction
    self.timestamp = timestamp
  }
}

// MARK: - Configuration

/// Configuration for the card stack appearance and behavior
public struct CardStackConfiguration: Sendable {
  public let maxVisibleCards: Int
  public let swipeThreshold: Double
  public let cardOffset: CGFloat
  public let cardScale: CGFloat
  public let animationDuration: Double
  public let enableUndo: Bool
  public let preloadThreshold: Int
  
  public init(
    maxVisibleCards: Int = 5,
    swipeThreshold: Double = 0.5,
    cardOffset: CGFloat = 10,
    cardScale: CGFloat = 0.1,
    animationDuration: Double = 0.3,
    enableUndo: Bool = true,
    preloadThreshold: Int = 3
  ) {
    self.maxVisibleCards = maxVisibleCards
    self.swipeThreshold = swipeThreshold
    self.cardOffset = cardOffset
    self.cardScale = cardScale
    self.animationDuration = animationDuration
    self.enableUndo = enableUndo
    self.preloadThreshold = preloadThreshold
  }
  
  public static let `default` = CardStackConfiguration()
}