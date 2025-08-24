//
//  ExampleApp.swift
//  AsyncCardStack Example
//
//  Created by Anirudh Lath on 2025-08-23.
//

import SwiftUI
import AsyncCardStack

@main
struct ExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

// MARK: - Example Card Model

struct ExampleCard: CardElement {
  let id: String
  let title: String
  let description: String
  let color: Color
  let imageSystemName: String
  
  static var examples: [ExampleCard] {
    [
      ExampleCard(
        id: "1",
        title: "SwiftUI",
        description: "Build beautiful apps across all Apple platforms",
        color: .blue,
        imageSystemName: "swift"
      ),
      ExampleCard(
        id: "2",
        title: "Async/Await",
        description: "Modern concurrency with Swift",
        color: .purple,
        imageSystemName: "arrow.triangle.2.circlepath"
      ),
      ExampleCard(
        id: "3",
        title: "Clean Architecture",
        description: "SOLID principles and separation of concerns",
        color: .green,
        imageSystemName: "building.2"
      ),
      ExampleCard(
        id: "4",
        title: "Reactive Updates",
        description: "Automatic UI updates with data changes",
        color: .orange,
        imageSystemName: "arrow.clockwise"
      ),
      ExampleCard(
        id: "5",
        title: "Type Safety",
        description: "Strong typing with Swift generics",
        color: .red,
        imageSystemName: "checkmark.shield"
      )
    ]
  }
}

// MARK: - Main Content View

struct ContentView: View {
  @StateObject private var continuationDataSource = ContinuationDataSource<ExampleCard>()
  @StateObject private var viewModel: CardStackViewModel<ExampleCard, LeftRight, ContinuationDataSource<ExampleCard>>
  
  @State private var swipedCards: [ExampleCard] = []
  @State private var currentDirection: LeftRight?
  
  init() {
    let dataSource = ContinuationDataSource<ExampleCard>()
    _continuationDataSource = StateObject(wrappedValue: dataSource)
    _viewModel = StateObject(wrappedValue: CardStackViewModel(
      dataSource: dataSource,
      configuration: CardStackConfiguration(
        maxVisibleCards: 3,
        swipeThreshold: 0.3,
        cardOffset: 15,
        cardScale: 0.05,
        animationDuration: 0.25,
        enableUndo: true,
        preloadThreshold: 2
      )
    ))
  }
  
  var body: some View {
    NavigationView {
      VStack(spacing: 20) {
        // Header
        headerView
        
        // Card Stack
        AsyncCardStack(
          viewModel: viewModel,
          onChange: { direction in
            currentDirection = direction
          }
        ) { card, direction in
          ExampleCardView(
            card: card,
            direction: direction ?? currentDirection
          )
        }
        .frame(maxHeight: 500)
        .padding(.horizontal)
        
        // Action Buttons
        actionButtons
        
        // Stats
        statsView
      }
      .navigationTitle("AsyncCardStack Demo")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        loadInitialCards()
        setupSwipeHandlers()
      }
    }
  }
  
  // MARK: - Views
  
  private var headerView: some View {
    VStack(spacing: 8) {
      if let direction = currentDirection {
        Label(
          direction == .left ? "Dislike" : "Like",
          systemImage: direction == .left ? "hand.thumbsdown.fill" : "hand.thumbsup.fill"
        )
        .foregroundColor(direction == .left ? .red : .green)
        .font(.headline)
        .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(height: 30)
    .animation(.easeInOut, value: currentDirection)
  }
  
  private var actionButtons: some View {
    HStack(spacing: 40) {
      // Undo button
      Button {
        Task {
          await viewModel.undo()
        }
      } label: {
        Image(systemName: "arrow.uturn.backward")
          .font(.title2)
          .foregroundColor(.orange)
          .frame(width: 60, height: 60)
          .background(Circle().fill(Color.orange.opacity(0.1)))
      }
      .disabled(!viewModel.state.canUndo)
      
      // Dislike button
      Button {
        Task {
          await viewModel.swipe(direction: .left)
        }
      } label: {
        Image(systemName: "xmark")
          .font(.title)
          .foregroundColor(.red)
          .frame(width: 60, height: 60)
          .background(Circle().fill(Color.red.opacity(0.1)))
      }
      
      // Like button
      Button {
        Task {
          await viewModel.swipe(direction: .right)
        }
      } label: {
        Image(systemName: "heart.fill")
          .font(.title)
          .foregroundColor(.green)
          .frame(width: 60, height: 60)
          .background(Circle().fill(Color.green.opacity(0.1)))
      }
      
      // Reload button
      Button {
        loadMoreCards()
      } label: {
        Image(systemName: "plus.circle.fill")
          .font(.title2)
          .foregroundColor(.blue)
          .frame(width: 60, height: 60)
          .background(Circle().fill(Color.blue.opacity(0.1)))
      }
    }
    .padding()
  }
  
  private var statsView: some View {
    HStack(spacing: 30) {
      VStack {
        Text("\(viewModel.state.remainingCards)")
          .font(.title2.bold())
        Text("Remaining")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      VStack {
        Text("\(swipedCards.filter { _ in true }.count)")
          .font(.title2.bold())
          .foregroundColor(.green)
        Text("Liked")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      VStack {
        Text("\(viewModel.state.swipeHistory.count)")
          .font(.title2.bold())
          .foregroundColor(.blue)
        Text("Total Swipes")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }
  
  // MARK: - Methods
  
  private func loadInitialCards() {
    continuationDataSource.sendInitialCards(ExampleCard.examples)
  }
  
  private func loadMoreCards() {
    let newCards = (6...10).map { index in
      ExampleCard(
        id: "\(index)",
        title: "Card \(index)",
        description: "Additional card loaded dynamically",
        color: Color(hue: Double(index) / 10, saturation: 0.8, brightness: 0.9),
        imageSystemName: "number.\(index).circle"
      )
    }
    continuationDataSource.appendCards(newCards)
  }
  
  private func setupSwipeHandlers() {
    viewModel.onSwipe = { card, direction in
      swipedCards.append(card)
      print("Swiped \(card.title) to \(direction)")
      
      // Simulate async validation
      try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
      return true
    }
    
    viewModel.onUndo = { card in
      swipedCards.removeAll { $0.id == card.id }
      print("Undid swipe for \(card.title)")
      return true
    }
  }
}

// MARK: - Card View

struct ExampleCardView: View {
  let card: ExampleCard
  let direction: LeftRight?
  
  var body: some View {
    VStack(spacing: 20) {
      // Icon
      Image(systemName: card.imageSystemName)
        .font(.system(size: 60))
        .foregroundColor(.white)
      
      // Title
      Text(card.title)
        .font(.largeTitle.bold())
        .foregroundColor(.white)
      
      // Description
      Text(card.description)
        .font(.body)
        .foregroundColor(.white.opacity(0.9))
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      
      Spacer()
      
      // Direction indicator
      if let direction = direction {
        HStack {
          if direction == .left {
            Label("NOPE", systemImage: "xmark")
              .font(.title2.bold())
              .foregroundColor(.red)
              .padding()
              .background(Capsule().fill(Color.white))
          } else {
            Label("LIKE", systemImage: "heart.fill")
              .font(.title2.bold())
              .foregroundColor(.green)
              .padding()
              .background(Capsule().fill(Color.white))
          }
        }
        .transition(.scale.combined(with: .opacity))
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      LinearGradient(
        colors: [card.color, card.color.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .cornerRadius(20)
    .shadow(radius: 10)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(
          direction == .left ? Color.red :
            direction == .right ? Color.green : Color.clear,
          lineWidth: 4
        )
        .animation(.easeInOut, value: direction)
    )
  }
}