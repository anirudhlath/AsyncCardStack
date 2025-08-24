//
//  CardView.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import SwiftUI

/// Individual card view with drag gesture handling
struct CardView<Element: CardElement, Direction: SwipeDirection, Content: View>: View {
  
  // MARK: - Environment & State
  
  @Environment(\.cardStackConfiguration) private var configuration: CardStackConfiguration
  
  @State private var translation: CGSize = .zero
  @State private var draggingState: DraggingState = .idle
  @GestureState private var isDragging: Bool = false
  
  // MARK: - Properties
  
  let card: Element
  let isOnTop: Bool
  let stackIndex: Int
  let offset: CGSize
  let onChange: ((Direction?) -> Void)?
  let onSwipe: (Direction) async -> Void
  let content: (Element, Direction?) -> Content
  
  init(
    card: Element,
    isOnTop: Bool,
    stackIndex: Int,
    offset: CGSize,
    onChange: ((Direction?) -> Void)? = nil,
    onSwipe: @escaping (Direction) async -> Void,
    content: @escaping (Element, Direction?) -> Content
  ) {
    self.card = card
    self.isOnTop = isOnTop
    self.stackIndex = stackIndex
    self.offset = offset
    self.onChange = onChange
    self.onSwipe = onSwipe
    self.content = content
  }
  
  private enum DraggingState {
    case idle
    case dragging
    case ended
  }
  
  // MARK: - Body
  
  var body: some View {
    GeometryReader { geometry in
      content(card, ongoingSwipeDirection(geometry))
        .disabled(translation != .zero)
        .offset(combinedOffset)
        .rotationEffect(rotation(geometry))
        .scaleEffect(cardScale, anchor: .bottom)  // Match legacy: scale from bottom
        .opacity(cardOpacity)
        .simultaneousGesture(isOnTop ? dragGesture(geometry) : nil)
        .animation(
          draggingState == .dragging ? .interactiveSpring(response: 0.3, dampingFraction: 0.8) : configuration.animationStyle.animation,
          value: translation
        )
        .animation(configuration.animationStyle.animation, value: offset)
        .onChange(of: isDragging) { newValue in
          if !newValue && draggingState == .dragging {
            cancelDragging()
          }
        }
    }
  }
  
  // MARK: - Computed Properties
  
  private var combinedOffset: CGSize {
    CGSize(
      width: offset.width + translation.width + cardStackOffset.width,
      height: offset.height + translation.height + cardStackOffset.height
    )
  }
  
  private var cardStackOffset: CGSize {
    guard stackIndex > 0 else { return .zero }
    return CGSize(width: 0, height: CGFloat(stackIndex) * configuration.cardOffset)
  }
  
  private var cardScale: CGFloat {
    guard stackIndex >= 0 else { return 1 }
    return 1 - configuration.cardScale * CGFloat(stackIndex)
  }
  
  private var cardOpacity: Double {
    stackIndex < 0 ? 0 : 1
  }
  
  // MARK: - Methods
  
  private func rotation(_ geometry: GeometryProxy) -> Angle {
    .degrees(Double(combinedOffset.width / geometry.size.width) * 15)
  }
  
  private func ongoingSwipeDirection(_ geometry: GeometryProxy) -> Direction? {
    guard translation != .zero else { return nil }
    
    let angle = Angle(radians: atan2(-translation.height, translation.width))
    guard let direction = Direction.from(angle: angle) else { return nil }
    
    let threshold = min(geometry.size.width, geometry.size.height) * configuration.swipeThreshold
    let distance = hypot(combinedOffset.width, combinedOffset.height)
    
    return distance > threshold ? direction : nil
  }
  
  private func dragGesture(_ geometry: GeometryProxy) -> some Gesture {
    DragGesture()
      .updating($isDragging) { value, state, transaction in
        state = true
      }
      .onChanged { value in
        self.draggingState = .dragging
        self.translation = value.translation
        if let ongoingDirection = ongoingSwipeDirection(geometry) {
          onChange?(ongoingDirection)
        } else {
          onChange?(nil)
        }
      }
      .onEnded { value in
        self.draggingState = .ended
        if let direction = ongoingSwipeDirection(geometry) {
          withAnimation(configuration.animationStyle.animation) {
            translation = .zero
          }
          Task {
            await onSwipe(direction)
          }
        } else {
          withAnimation(configuration.animationStyle.animation) {
            cancelDragging()
          }
        }
      }
  }
  
  private func cancelDragging() {
    draggingState = .idle
    translation = .zero
  }
}