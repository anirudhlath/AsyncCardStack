//
//  SwipeDirectionFixTests.swift
//  AsyncCardStackTests
//
//  Created by Feature Developer on 8/23/25.
//
//  Tests to verify swipe direction detection matches legacy CardStack behavior

import XCTest
import SwiftUI
@testable import AsyncCardStack

final class SwipeDirectionFixTests: XCTestCase {
  
  func testLeftRightSwipeDetection() {
    // Test angles that should be detected as LEFT
    // Legacy: 3π/4 (135°) to 5π/4 (225°) - note: 225° is exclusive
    XCTAssertEqual(LeftRight.from(angle: .degrees(135)), .left, "135° should be left")
    XCTAssertEqual(LeftRight.from(angle: .degrees(180)), .left, "180° should be left")
    XCTAssertEqual(LeftRight.from(angle: .degrees(224)), .left, "224° should be left")
    XCTAssertEqual(LeftRight.from(angle: .degrees(200)), .left, "200° should be left")
    
    // Test angles that should be detected as RIGHT
    // Legacy: 0 to π/4 (45°) and 7π/4 (315°) to 2π (360°)
    XCTAssertEqual(LeftRight.from(angle: .degrees(0)), .right, "0° should be right")
    XCTAssertEqual(LeftRight.from(angle: .degrees(30)), .right, "30° should be right")
    XCTAssertEqual(LeftRight.from(angle: .degrees(44)), .right, "44° should be right")
    XCTAssertEqual(LeftRight.from(angle: .degrees(315)), .right, "315° should be right")
    XCTAssertEqual(LeftRight.from(angle: .degrees(330)), .right, "330° should be right")
    XCTAssertEqual(LeftRight.from(angle: .degrees(359)), .right, "359° should be right")
    
    // Test angles that should return nil (dead zones for up/down)
    XCTAssertNil(LeftRight.from(angle: .degrees(90)), "90° (up) should be nil")
    XCTAssertNil(LeftRight.from(angle: .degrees(270)), "270° (down) should be nil")
    XCTAssertNil(LeftRight.from(angle: .degrees(60)), "60° should be nil")
    XCTAssertNil(LeftRight.from(angle: .degrees(120)), "120° should be nil")
    XCTAssertNil(LeftRight.from(angle: .degrees(240)), "240° should be nil")
    XCTAssertNil(LeftRight.from(angle: .degrees(300)), "300° should be nil")
  }
  
  func testSwipeDirectionFromDragTranslation() {
    // Simulate drag gestures and verify correct direction detection
    // Drag translation uses atan2(-height, width) to calculate angle
    
    // Swipe RIGHT: positive width, minimal height
    let rightAngle = Angle(radians: atan2(-0, 100))  // Pure right
    XCTAssertEqual(LeftRight.from(angle: rightAngle), .right, "Horizontal right swipe")
    
    // Swipe LEFT: negative width, minimal height
    let leftAngle = Angle(radians: atan2(-0, -100))  // Pure left
    XCTAssertEqual(LeftRight.from(angle: leftAngle), .left, "Horizontal left swipe")
    
    // Swipe RIGHT-UP: positive width, negative height (upward in screen coords)
    let rightUpAngle = Angle(radians: atan2(50, 100))  // 45° up-right
    XCTAssertEqual(LeftRight.from(angle: rightUpAngle), .right, "Diagonal right-up swipe")
    
    // Swipe LEFT-UP: negative width, negative height
    let leftUpAngle = Angle(radians: atan2(50, -100))  // 135° up-left
    XCTAssertEqual(LeftRight.from(angle: leftUpAngle), .left, "Diagonal left-up swipe")
    
    // Swipe RIGHT-DOWN: positive width, positive height (downward in screen coords)
    let rightDownAngle = Angle(radians: atan2(-50, 100))  // -45° down-right
    XCTAssertEqual(LeftRight.from(angle: rightDownAngle), .right, "Diagonal right-down swipe")
    
    // Swipe LEFT-DOWN: negative width, positive height
    let leftDownAngle = Angle(radians: atan2(-50, -100))  // -135° down-left
    XCTAssertEqual(LeftRight.from(angle: leftDownAngle), .left, "Diagonal left-down swipe")
    
    // Swipe UP: minimal width, negative height (should be nil - dead zone)
    let upAngle = Angle(radians: atan2(100, 0))  // 90° up
    XCTAssertNil(LeftRight.from(angle: upAngle), "Vertical up swipe should be nil")
    
    // Swipe DOWN: minimal width, positive height (should be nil - dead zone)
    let downAngle = Angle(radians: atan2(-100, 0))  // -90° down
    XCTAssertNil(LeftRight.from(angle: downAngle), "Vertical down swipe should be nil")
  }
  
  func testAngleNormalization() {
    // Test that negative angles are properly normalized
    let negativeAngle = Angle(radians: -Double.pi / 2)  // -90°
    let normalized = negativeAngle.normalized
    XCTAssertEqual(normalized.radians, 3 * Double.pi / 2, accuracy: 0.001, "Negative angle should normalize to positive")
    
    // Test normalized angle detection
    XCTAssertNil(LeftRight.from(angle: negativeAngle), "-90° should normalize to 270° and return nil")
  }
  
  func testBoundaryAngles() {
    // Test exact boundary angles
    
    // 3π/4 (135°) - start of left zone
    XCTAssertEqual(LeftRight.from(angle: .radians(3 * .pi / 4)), .left, "135° boundary should be left")
    
    // Just before 3π/4
    XCTAssertNil(LeftRight.from(angle: .radians(3 * .pi / 4 - 0.01)), "Just before 135° should be nil")
    
    // 5π/4 (225°) - end of left zone (exclusive)
    XCTAssertNil(LeftRight.from(angle: .radians(5 * .pi / 4)), "225° boundary should be nil")
    
    // Just before 5π/4
    XCTAssertEqual(LeftRight.from(angle: .radians(5 * .pi / 4 - 0.01)), .left, "Just before 225° should be left")
    
    // π/4 (45°) - end of right zone (exclusive)
    XCTAssertNil(LeftRight.from(angle: .radians(.pi / 4)), "45° boundary should be nil")
    
    // Just before π/4
    XCTAssertEqual(LeftRight.from(angle: .radians(.pi / 4 - 0.01)), .right, "Just before 45° should be right")
    
    // 7π/4 (315°) - start of right zone
    XCTAssertEqual(LeftRight.from(angle: .radians(7 * .pi / 4)), .right, "315° boundary should be right")
    
    // Just before 7π/4
    XCTAssertNil(LeftRight.from(angle: .radians(7 * .pi / 4 - 0.01)), "Just before 315° should be nil")
  }
}