//
//  DataSources.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import Foundation

// MARK: - Static Data Source

/// A data source that provides a static array of cards
public final class StaticCardDataSource<Element: CardElement>: CardDataSource, @unchecked Sendable {
  private let cards: [Element]
  private var hasLoadedInitial = false
  
  public init(cards: [Element]) {
    self.cards = cards
  }
  
  public var cardStream: AsyncStream<CardUpdate<Element>> {
    get async throws {
      AsyncStream { continuation in
        // For static data, we just send initial cards and finish
        continuation.yield(.initial(cards))
        continuation.finish()
      }
    }
  }
  
  public func loadInitialCards() async throws -> [Element] {
    hasLoadedInitial = true
    return cards
  }
  
  public func loadMoreCards() async throws -> [Element] {
    // Static source has no more cards to load
    return []
  }
  
  public func reportSwipe(card: Element, direction: any SwipeDirection) async throws {
    // No-op for static source
  }
  
  public func reportUndo(card: Element) async throws {
    // No-op for static source
  }
}

// MARK: - AsyncSequence Data Source

/// A data source that wraps an AsyncSequence
public final class AsyncSequenceDataSource<Element: CardElement, S: AsyncSequence & Sendable>: CardDataSource, @unchecked Sendable where S.Element == [Element] {
  private let sequence: S
  private var iterator: S.AsyncIterator?
  private var continuation: AsyncStream<CardUpdate<Element>>.Continuation?
  private var streamTask: Task<Void, Never>?
  
  public init(sequence: S) {
    self.sequence = sequence
  }
  
  deinit {
    streamTask?.cancel()
  }
  
  public var cardStream: AsyncStream<CardUpdate<Element>> {
    get async throws {
      AsyncStream { continuation in
        self.continuation = continuation
        
        streamTask = Task {
          var iterator = sequence.makeAsyncIterator()
          var isFirst = true
          
          do {
            while let cards = try await iterator.next() {
              if Task.isCancelled { break }
              
              if isFirst {
                continuation.yield(.initial(cards))
                isFirst = false
              } else {
                continuation.yield(.replace(cards))
              }
            }
          } catch {
            // Handle error if needed
            print("AsyncSequence error: \(error)")
          }
          
          continuation.finish()
        }
      }
    }
  }
  
  public func loadInitialCards() async throws -> [Element] {
    // Initial cards are provided through the stream
    return []
  }
  
  public func loadMoreCards() async throws -> [Element] {
    // Cards come from the async sequence
    return []
  }
  
  public func reportSwipe(card: Element, direction: any SwipeDirection) async throws {
    // No-op for async sequence source
  }
  
  public func reportUndo(card: Element) async throws {
    // No-op for async sequence source
  }
}

// MARK: - AsyncStream Bridge Data Source

/// A data source that bridges an AsyncStream directly
public final class AsyncStreamDataSource<Element: CardElement>: CardDataSource {
  private let stream: AsyncStream<CardUpdate<Element>>
  private let swipeHandler: (@Sendable (Element, any SwipeDirection) async throws -> Void)?
  private let undoHandler: (@Sendable (Element) async throws -> Void)?
  private let loadMoreHandler: (@Sendable () async throws -> [Element])?
  
  public init(
    stream: AsyncStream<CardUpdate<Element>>,
    onSwipe: (@Sendable (Element, any SwipeDirection) async throws -> Void)? = nil,
    onUndo: (@Sendable (Element) async throws -> Void)? = nil,
    onLoadMore: (@Sendable () async throws -> [Element])? = nil
  ) {
    self.stream = stream
    self.swipeHandler = onSwipe
    self.undoHandler = onUndo
    self.loadMoreHandler = onLoadMore
  }
  
  public var cardStream: AsyncStream<CardUpdate<Element>> {
    get async throws {
      stream
    }
  }
  
  public func loadInitialCards() async throws -> [Element] {
    // Initial cards come through the stream
    return []
  }
  
  public func loadMoreCards() async throws -> [Element] {
    if let handler = loadMoreHandler {
      return try await handler()
    }
    return []
  }
  
  public func reportSwipe(card: Element, direction: any SwipeDirection) async throws {
    if let handler = swipeHandler {
      try await handler(card, direction)
    }
  }
  
  public func reportUndo(card: Element) async throws {
    if let handler = undoHandler {
      try await handler(card)
    }
  }
}

// MARK: - Continuation-based Data Source

/// A data source that uses AsyncStream.Continuation for manual control
public final class ContinuationDataSource<Element: CardElement>: CardDataSource, @unchecked Sendable {
  private var continuation: AsyncStream<CardUpdate<Element>>.Continuation?
  private let stream: AsyncStream<CardUpdate<Element>>
  
  public init() {
    var localContinuation: AsyncStream<CardUpdate<Element>>.Continuation?
    self.stream = AsyncStream { continuation in
      localContinuation = continuation
    }
    self.continuation = localContinuation
  }
  
  deinit {
    continuation?.finish()
  }
  
  public var cardStream: AsyncStream<CardUpdate<Element>> {
    get async throws {
      stream
    }
  }
  
  // MARK: - Public Control Methods
  
  public func sendInitialCards(_ cards: [Element]) {
    continuation?.yield(.initial(cards))
  }
  
  public func appendCards(_ cards: [Element]) {
    continuation?.yield(.append(cards))
  }
  
  public func replaceCards(_ cards: [Element]) {
    continuation?.yield(.replace(cards))
  }
  
  public func removeCards(ids: Set<Element.ID>) {
    continuation?.yield(.remove(ids))
  }
  
  public func updateCard(_ card: Element) {
    continuation?.yield(.update(card))
  }
  
  public func clearCards() {
    continuation?.yield(.clear)
  }
  
  public func finish() {
    continuation?.finish()
  }
  
  // MARK: - Protocol Requirements
  
  public func loadInitialCards() async throws -> [Element] {
    // Initial cards are sent through continuation
    return []
  }
  
  public func loadMoreCards() async throws -> [Element] {
    // Cards are managed through continuation
    return []
  }
  
  public func reportSwipe(card: Element, direction: any SwipeDirection) async throws {
    // Override in subclass if needed
  }
  
  public func reportUndo(card: Element) async throws {
    // Override in subclass if needed
  }
}