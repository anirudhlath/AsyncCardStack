//
//  SwipeDirectionTests.swift
//  AsyncCardStackTests
//
//  Created by Test Engineer on 2025-08-23.
//

import XCTest
import SwiftUI
@testable import AsyncCardStack

// MARK: - SwipeDirection Tests

final class SwipeDirectionTests: XCTestCase {
  
  // MARK: - Angle Normalization Tests
  
  func test_angleNormalization_positiveAngles() {
    // Given
    let angle1 = Angle(radians: .pi / 2)
    let angle2 = Angle(radians: 3 * .pi)
    
    // When
    let normalized1 = angle1.normalized
    let normalized2 = angle2.normalized
    
    // Then
    XCTAssertEqual(normalized1.radians, .pi / 2, accuracy: 0.001)
    XCTAssertEqual(normalized2.radians, .pi, accuracy: 0.001)
  }
  
  func test_angleNormalization_negativeAngles() {
    // Given
    let angle = Angle(radians: -.pi / 2)
    
    // When
    let normalized = angle.normalized
    
    // Then
    XCTAssertEqual(normalized.radians, 3 * .pi / 2, accuracy: 0.001)
  }
  
  // MARK: - LeftRight Direction Tests
  
  func test_leftRight_fromAngle() {
    // Test left direction
    XCTAssertEqual(LeftRight.from(angle: .radians(.pi)), .left)
    XCTAssertEqual(LeftRight.from(angle: .degrees(180)), .left)
    
    // Test right direction
    XCTAssertEqual(LeftRight.from(angle: .zero), .right)
    XCTAssertEqual(LeftRight.from(angle: .degrees(0)), .right)
    XCTAssertEqual(LeftRight.from(angle: .degrees(350)), .right)
    
    // Test boundaries
    XCTAssertEqual(LeftRight.from(angle: .degrees(135)), .left)
    XCTAssertEqual(LeftRight.from(angle: .degrees(225)), .left)
    XCTAssertEqual(LeftRight.from(angle: .degrees(45)), .right)
    XCTAssertEqual(LeftRight.from(angle: .degrees(315)), .right)
    
    // Test nil cases (up/down)
    XCTAssertNil(LeftRight.from(angle: .degrees(90)))
    XCTAssertNil(LeftRight.from(angle: .degrees(270)))
  }
  
  func test_leftRight_angle() {
    // Given
    let left = LeftRight.left
    let right = LeftRight.right
    
    // Then
    XCTAssertEqual(left.angle.radians, .pi, accuracy: 0.001)
    XCTAssertEqual(right.angle.radians, 0, accuracy: 0.001)
  }
  
  func test_leftRight_caseIterable() {
    // Given
    let allCases = LeftRight.allCases
    
    // Then
    XCTAssertEqual(allCases.count, 2)
    XCTAssertTrue(allCases.contains(.left))
    XCTAssertTrue(allCases.contains(.right))
  }
  
  // MARK: - FourDirections Tests
  
  func test_fourDirections_fromAngle() {
    // Test cardinal directions
    XCTAssertEqual(FourDirections.from(angle: .degrees(0)), .right)
    XCTAssertEqual(FourDirections.from(angle: .degrees(90)), .top)
    XCTAssertEqual(FourDirections.from(angle: .degrees(180)), .left)
    XCTAssertEqual(FourDirections.from(angle: .degrees(270)), .bottom)
    
    // Test diagonal angles
    XCTAssertEqual(FourDirections.from(angle: .degrees(45)), .top)
    XCTAssertEqual(FourDirections.from(angle: .degrees(135)), .left)
    XCTAssertEqual(FourDirections.from(angle: .degrees(225)), .left)
    XCTAssertEqual(FourDirections.from(angle: .degrees(315)), .right)
    
    // Test boundaries
    XCTAssertEqual(FourDirections.from(angle: .degrees(44)), .right)
    XCTAssertEqual(FourDirections.from(angle: .degrees(46)), .top)
    XCTAssertEqual(FourDirections.from(angle: .degrees(134)), .top)
    XCTAssertEqual(FourDirections.from(angle: .degrees(136)), .left)
  }
  
  func test_fourDirections_angle() {
    // Given
    let directions: [(FourDirections, Double)] = [
      (.top, 90),
      (.right, 0),
      (.bottom, 270),
      (.left, 180)
    ]
    
    // Then
    for (direction, expectedDegrees) in directions {
      XCTAssertEqual(direction.angle.degrees, expectedDegrees, accuracy: 0.001)
    }
  }
  
  func test_fourDirections_caseIterable() {
    // Given
    let allCases = FourDirections.allCases
    
    // Then
    XCTAssertEqual(allCases.count, 4)
    XCTAssertTrue(allCases.contains(.top))
    XCTAssertTrue(allCases.contains(.right))
    XCTAssertTrue(allCases.contains(.bottom))
    XCTAssertTrue(allCases.contains(.left))
  }
  
  // MARK: - EightDirections Tests
  
  func test_eightDirections_fromAngle() {
    // Test all eight directions
    let testCases: [(Double, EightDirections)] = [
      (0, .right),
      (45, .topRight),
      (90, .top),
      (135, .topLeft),
      (180, .left),
      (225, .bottomLeft),
      (270, .bottom),
      (315, .bottomRight),
      (360, .right)
    ]
    
    for (degrees, expected) in testCases {
      XCTAssertEqual(
        EightDirections.from(angle: .degrees(degrees)),
        expected,
        "Failed for \(degrees) degrees"
      )
    }
  }
  
  func test_eightDirections_boundaries() {
    // Test boundary conditions
    XCTAssertEqual(EightDirections.from(angle: .degrees(22.4)), .right)
    XCTAssertEqual(EightDirections.from(angle: .degrees(22.6)), .topRight)
    XCTAssertEqual(EightDirections.from(angle: .degrees(67.4)), .topRight)
    XCTAssertEqual(EightDirections.from(angle: .degrees(67.6)), .top)
    XCTAssertEqual(EightDirections.from(angle: .degrees(112.4)), .top)
    XCTAssertEqual(EightDirections.from(angle: .degrees(112.6)), .topLeft)
  }
  
  func test_eightDirections_angle() {
    // Given
    let directions: [(EightDirections, Double)] = [
      (.top, 90),
      (.topRight, 45),
      (.right, 0),
      (.bottomRight, 315),
      (.bottom, 270),
      (.bottomLeft, 225),
      (.left, 180),
      (.topLeft, 135)
    ]
    
    // Then
    for (direction, expectedDegrees) in directions {
      XCTAssertEqual(
        direction.angle.degrees,
        expectedDegrees,
        accuracy: 0.001,
        "Failed for \(direction)"
      )
    }
  }
  
  func test_eightDirections_caseIterable() {
    // Given
    let allCases = EightDirections.allCases
    
    // Then
    XCTAssertEqual(allCases.count, 8)
    for direction in EightDirections.allCases {
      XCTAssertTrue(allCases.contains(direction))
    }
  }
  
  // MARK: - Protocol Conformance Tests
  
  func test_swipeDirection_equatable() {
    // LeftRight
    XCTAssertEqual(LeftRight.left, LeftRight.left)
    XCTAssertNotEqual(LeftRight.left, LeftRight.right)
    
    // FourDirections
    XCTAssertEqual(FourDirections.top, FourDirections.top)
    XCTAssertNotEqual(FourDirections.top, FourDirections.bottom)
    
    // EightDirections
    XCTAssertEqual(EightDirections.topRight, EightDirections.topRight)
    XCTAssertNotEqual(EightDirections.topRight, EightDirections.bottomLeft)
  }
  
  func test_swipeDirection_sendable() {
    // This test verifies that our direction types conform to Sendable
    // The actual test is that this compiles
    func requiresSendable<T: Sendable>(_ value: T) {
      _ = value
    }
    
    requiresSendable(LeftRight.left)
    requiresSendable(FourDirections.top)
    requiresSendable(EightDirections.topRight)
  }
  
  // MARK: - Edge Cases
  
  func test_negativeAngles() {
    // Given negative angles
    let angles: [Double] = [-45, -90, -180, -270, -360]
    
    // Then - should handle correctly
    for degrees in angles {
      let angle = Angle(degrees: degrees)
      
      // Should not crash
      _ = LeftRight.from(angle: angle)
      _ = FourDirections.from(angle: angle)
      _ = EightDirections.from(angle: angle)
    }
  }
  
  func test_largeAngles() {
    // Given angles > 360
    let angles: [Double] = [450, 720, 1080]
    
    // Then - should normalize and handle correctly
    for degrees in angles {
      let angle = Angle(degrees: degrees)
      
      // Should not crash
      _ = LeftRight.from(angle: angle)
      _ = FourDirections.from(angle: angle)
      _ = EightDirections.from(angle: angle)
    }
  }
  
  // MARK: - Performance Tests
  
  func test_directionFromAngle_performance() {
    measure {
      for _ in 0..<1000 {
        let randomAngle = Angle(degrees: Double.random(in: 0..<360))
        _ = LeftRight.from(angle: randomAngle)
        _ = FourDirections.from(angle: randomAngle)
        _ = EightDirections.from(angle: randomAngle)
      }
    }
  }
}