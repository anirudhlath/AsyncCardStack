//
//  UndoConfiguration.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import Foundation

// MARK: - Collection Replacement Strategy

/// Defines how to handle undo history when the entire card collection is replaced
public enum CollectionReplacementStrategy: Sendable {
  /// Clear all tombstones when collection is replaced (safest, default)
  case clearTombstones
  
  /// Preserve tombstones for cards that still exist in the new collection
  case preserveValidTombstones
  
  /// Block collection replacement if there are tombstones (requires user action)
  case blockIfTombstones
  
  /// Ask user for confirmation before clearing tombstones
  case askUser
}

// MARK: - Restore on Launch Strategy

/// Defines how to handle persisted tombstones when the app launches
public enum RestoreOnLaunchStrategy: Sendable {
  /// Restore tombstones from local storage and keep them in undo history
  case restore
  
  /// Restore tombstones but immediately evict them (calls onEviction for each)
  case clearGracefully
  
  /// Don't restore tombstones, start with empty undo history
  case ignore
}

// MARK: - Undo Configuration

/// Configuration for the undo functionality
public struct UndoConfiguration<Element: CardElement, Direction: SwipeDirection>: Sendable {
  
  /// Maximum number of cards that can be undone
  public let limit: Int
  
  /// Strategy for handling collection replacement
  public let replacementStrategy: CollectionReplacementStrategy
  
  /// Strategy for handling persisted tombstones on app launch
  /// - Note: If persistence is not available (types don't conform to Codable), this will be ignored
  public let restoreOnLaunch: RestoreOnLaunchStrategy
  
  /// Persistence key for storing tombstones locally
  /// - Note: Set to nil to disable persistence, even if types conform to Codable
  public let persistenceKey: String?
  
  /// Callback when a card is evicted from the undo history (exits the undo window)
  /// This is where you would actually delete the card from your backend
  public let onEviction: (@Sendable (Element, Direction) async -> Void)?
  
  /// Optional validation before allowing undo
  /// Return false to prevent the undo
  public let onUndoValidation: (@Sendable (Element) async -> Bool)?
  
  /// Callback for user confirmation when strategy is .askUser
  public let onConfirmReplacement: (@Sendable () async -> Bool)?
  
  /// Internal flag to track if persistence was requested
  internal let persistenceRequested: Bool
  
  /// Creates an undo configuration
  /// - Parameters:
  ///   - limit: Maximum number of cards that can be undone (default: 5)
  ///   - replacementStrategy: Strategy for handling collection replacement (default: .clearTombstones)
  ///   - restoreOnLaunch: Strategy for restoring persisted tombstones (default: .restore)
  ///   - persistenceKey: Key for storing tombstones. Set to nil to disable persistence (default: "AsyncCardStack.Tombstones")
  ///   - onEviction: Callback when a card is evicted from undo history
  ///   - onUndoValidation: Optional validation before allowing undo
  ///   - onConfirmReplacement: Callback for user confirmation when strategy is .askUser
  /// - Note: Persistence only works when Element and Direction conform to Codable.
  ///         If persistence is requested but types don't conform to Codable, a runtime warning will be shown.
  public init(
    limit: Int = 5,
    replacementStrategy: CollectionReplacementStrategy = .clearTombstones,
    restoreOnLaunch: RestoreOnLaunchStrategy = .restore,
    persistenceKey: String? = "AsyncCardStack.Tombstones",
    onEviction: (@Sendable (Element, Direction) async -> Void)? = nil,
    onUndoValidation: (@Sendable (Element) async -> Bool)? = nil,
    onConfirmReplacement: (@Sendable () async -> Bool)? = nil
  ) {
    self.limit = limit
    self.replacementStrategy = replacementStrategy
    self.restoreOnLaunch = restoreOnLaunch
    self.persistenceKey = persistenceKey
    self.onEviction = onEviction
    self.onUndoValidation = onUndoValidation
    self.onConfirmReplacement = onConfirmReplacement
    self.persistenceRequested = (persistenceKey != nil)
  }
  
  /// Convenience initializer for explicitly disabling persistence
  public static var withoutPersistence: UndoConfiguration {
    UndoConfiguration(persistenceKey: nil)
  }
}

// MARK: - Tombstone

/// Internal representation of a swiped card that can be undone
internal struct Tombstone<Element: CardElement, Direction: SwipeDirection>: Sendable {
  let id: Element.ID
  let card: Element
  let direction: Direction
  let timestamp: Date
  
  init(card: Element, direction: Direction, timestamp: Date = Date()) {
    self.id = card.id
    self.card = card
    self.direction = direction
    self.timestamp = timestamp
  }
}