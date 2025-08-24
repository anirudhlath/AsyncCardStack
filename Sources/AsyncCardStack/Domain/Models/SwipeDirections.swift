//
//  SwipeDirections.swift
//  AsyncCardStack
//
//  Created by Anirudh Lath on 2025-08-23.
//

import Foundation
import SwiftUI

// MARK: - Angle Extensions

public extension Angle {
  /// Normalize angle to 0...2π range
  var normalized: Angle {
    let radians = self.radians.truncatingRemainder(dividingBy: 2 * .pi)
    return .radians(radians < 0 ? radians + 2 * .pi : radians)
  }
}

// MARK: - Built-in Swipe Directions

/// Two-direction swipe (left/right)
public enum LeftRight: String, SwipeDirection, CaseIterable {
  case left
  case right
  
  public static func from(angle: Angle) -> Self? {
    let normalized = angle.normalized.radians
    
    // Define dead zones for up/down (around 90° and 270°)
    let deadZone: Double = .pi / 8  // 22.5 degrees
    
    // Up zone: 90° ± deadZone
    if abs(normalized - .pi / 2) < deadZone {
      return nil  // Up
    }
    // Down zone: 270° ± deadZone
    if abs(normalized - 3 * .pi / 2) < deadZone {
      return nil  // Down
    }
    
    // Left: roughly 135° to 225°
    if normalized > .pi / 2 + deadZone && normalized < 3 * .pi / 2 - deadZone {
      return .left
    }
    
    // Right: everything else
    return .right
  }
  
  public var angle: Angle {
    switch self {
    case .left:
      return .radians(.pi)
    case .right:
      return .zero
    }
  }
}

/// Four-direction swipe (top/right/bottom/left)
public enum FourDirections: String, SwipeDirection, CaseIterable {
  case top
  case right
  case bottom
  case left
  
  public static func from(angle: Angle) -> Self? {
    let normalized = angle.normalized.radians
    
    // Use inclusive ranges for boundaries
    switch normalized {
    case .pi / 4 ..< 3 * .pi / 4:
      return .top
    case 3 * .pi / 4 ... 5 * .pi / 4:  // Include 5π/4 (225°)
      return .left
    case (5 * .pi / 4).nextUp ..< 7 * .pi / 4:
      return .bottom
    case 0 ..< .pi / 4, 7 * .pi / 4 ..< 2 * .pi:
      return .right
    default:
      return .right  // Catch any edge cases
    }
  }
  
  public var angle: Angle {
    switch self {
    case .top:
      return .radians(.pi / 2)
    case .right:
      return .zero
    case .bottom:
      return .radians(3 * .pi / 2)
    case .left:
      return .radians(.pi)
    }
  }
}

/// Eight-direction swipe
public enum EightDirections: String, SwipeDirection, CaseIterable {
  case top
  case topRight
  case right
  case bottomRight
  case bottom
  case bottomLeft
  case left
  case topLeft
  
  public static func from(angle: Angle) -> Self? {
    switch angle.normalized.degrees {
    case 22.5..<67.5:
      return .topRight
    case 67.5..<112.5:
      return .top
    case 112.5..<157.5:
      return .topLeft
    case 157.5..<202.5:
      return .left
    case 202.5..<247.5:
      return .bottomLeft
    case 247.5..<292.5:
      return .bottom
    case 292.5..<337.5:
      return .bottomRight
    default:
      return .right
    }
  }
  
  public var angle: Angle {
    switch self {
    case .top:
      return .degrees(90)
    case .topRight:
      return .degrees(45)
    case .right:
      return .zero
    case .bottomRight:
      return .degrees(315)
    case .bottom:
      return .degrees(270)
    case .bottomLeft:
      return .degrees(225)
    case .left:
      return .degrees(180)
    case .topLeft:
      return .degrees(135)
    }
  }
}