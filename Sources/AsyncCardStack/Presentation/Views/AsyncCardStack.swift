//
//  AsyncCardStack.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import SwiftUI

/// Main card stack view using async/await
public struct AsyncCardStack<Element: CardElement, Direction: SwipeDirection, DataSource: CardDataSource, Content: View>: View where DataSource.Element == Element {
  
  // MARK: - Properties
  
  @ObservedObject private var viewModel: CardStackViewModel<Element, Direction, DataSource>
  @State private var ongoingDirection: Direction?
  
  private let configuration: CardStackConfiguration
  private let content: (Element, Direction?) -> Content
  private let onChange: ((Direction?) -> Void)?
  
  // MARK: - Initialization
  
  public init(
    viewModel: CardStackViewModel<Element, Direction, DataSource>,
    configuration: CardStackConfiguration = .default,
    onChange: ((Direction?) -> Void)? = nil,
    @ViewBuilder content: @escaping (Element, Direction?) -> Content
  ) {
    self.viewModel = viewModel
    self.configuration = configuration
    self.onChange = onChange
    self.content = content
  }
  
  // MARK: - Body
  
  public var body: some View {
    let _ = print("🌟 AsyncCardStack.body: Recomputing view")
    let _ = print("🌟 AsyncCardStack.body: viewModel.state.cards.count = \(viewModel.state.cards.count)")
    let _ = print("🌟 AsyncCardStack.body: viewModel.state.visibleCards.count = \(viewModel.state.visibleCards.count)")
    
    ZStack {
      if viewModel.state.cards.isEmpty {
        emptyStateView
      } else {
        cardStackView
      }
    }
    .environment(\.cardStackConfiguration, configuration)
    .onAppear {
      viewModel.startListening()
    }
    .onDisappear {
      viewModel.stopListening()
    }
    .onChange(of: ongoingDirection) { newValue in
      onChange?(newValue)
    }
  }
  
  // MARK: - Views
  
  private var cardStackView: some View {
    GeometryReader { geometry in
      ZStack {
        // Render cards in reverse order (bottom cards first)
        ForEach(Array(viewModel.state.visibleCards.enumerated().reversed()), id: \.element.id) { index, card in
          makeCardView(
            card: card,
            index: index,
            geometry: geometry
          )
        }
      }
    }
  }
  
  @ViewBuilder
  private func makeCardView(card: Element, index: Int, geometry: GeometryProxy) -> some View {
    CardView(
      card: card,
      isOnTop: index == 0,
      stackIndex: index,
      offset: offset(for: getSwipeDirection(for: card), in: geometry),
      onChange: { direction in
        ongoingDirection = direction
      },
      onSwipe: { direction in
        await viewModel.swipe(direction: direction)
        ongoingDirection = nil
      },
      content: { element, direction in
        content(element, direction ?? ongoingDirection)
      }
    )
    .zIndex(Double(viewModel.state.visibleCards.count - index))
  }
  
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      if viewModel.state.isLoading {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle())
      } else if let error = viewModel.state.error {
        VStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)
            .foregroundColor(.orange)
          Text("Error loading cards")
            .font(.headline)
          Text(error.localizedDescription)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
      } else {
        VStack(spacing: 8) {
          Image(systemName: "rectangle.stack")
            .font(.largeTitle)
            .foregroundColor(.secondary)
          Text("No cards available")
            .font(.headline)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
  }
  
  // MARK: - Helper Methods
  
  private func getSwipeDirection(for card: Element) -> Direction? {
    // Get the swipe direction from state for animation
    return viewModel.state.getSwipeDirection(for: card.id)
  }
  
  private func offset(for direction: Direction?, in geometry: GeometryProxy) -> CGSize {
    guard let direction = direction else { return .zero }
    
    let angle = direction.angle
    let width = geometry.size.width
    let height = geometry.size.height
    
    return CGSize(
      width: cos(angle.radians) * width * 2.0,
      height: sin(angle.radians) * -height * 2.0
    )
  }
}

// MARK: - Environment Key

extension EnvironmentValues {
  private struct CardStackConfigurationKey: EnvironmentKey {
    static let defaultValue = CardStackConfiguration.default
  }
  
  public var cardStackConfiguration: CardStackConfiguration {
    get { self[CardStackConfigurationKey.self] }
    set { self[CardStackConfigurationKey.self] = newValue }
  }
}

// MARK: - Convenience Initializers

extension AsyncCardStack {
  /// Initialize with static cards
  public init(
    cards: [Element],
    configuration: CardStackConfiguration = .default,
    undoConfiguration: UndoConfiguration<Element, Direction>? = nil,
    onChange: ((Direction?) -> Void)? = nil,
    @ViewBuilder content: @escaping (Element, Direction?) -> Content
  ) where DataSource == StaticCardDataSource<Element> {
    let viewModel = CardStackViewModel(
      cards: cards,
      configuration: configuration,
      undoConfiguration: undoConfiguration
    )
    
    self.init(
      viewModel: viewModel,
      configuration: configuration,
      onChange: onChange,
      content: content
    )
  }
  
  /// Initialize with an AsyncStream
  public init(
    stream: AsyncStream<CardUpdate<Element>>,
    configuration: CardStackConfiguration = .default,
    undoConfiguration: UndoConfiguration<Element, Direction>? = nil,
    onChange: ((Direction?) -> Void)? = nil,
    onSwipe: (@Sendable (Element, Direction) async throws -> Void)? = nil,
    onUndo: (@Sendable (Element) async throws -> Void)? = nil,
    onLoadMore: (@Sendable () async throws -> [Element])? = nil,
    @ViewBuilder content: @escaping (Element, Direction?) -> Content
  ) where DataSource == AsyncStreamDataSource<Element> {
    let dataSource = AsyncStreamDataSource(
      stream: stream,
      onSwipe: onSwipe != nil ? { @Sendable element, direction in
        if let dir = direction as? Direction, let swipeHandler = onSwipe {
          try await swipeHandler(element, dir)
        }
      } : nil,
      onUndo: onUndo,
      onLoadMore: onLoadMore
    )
    
    let viewModel = CardStackViewModel(
      dataSource: dataSource,
      configuration: configuration,
      undoConfiguration: undoConfiguration
    )
    
    self.init(
      viewModel: viewModel,
      configuration: configuration,
      onChange: onChange,
      content: content
    )
  }
}