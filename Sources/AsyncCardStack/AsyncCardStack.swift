//
//  AsyncCardStack.swift
//  AsyncCardStack
//
//  Created by Software Architect on 2025-08-23.
//

// MARK: - Public API Exports

// Core Protocols
public typealias CardElement = CardStackProtocols.CardElement
public typealias SwipeDirection = CardStackProtocols.SwipeDirection
public typealias CardDataSource = CardStackProtocols.CardDataSource

// Models
public typealias CardUpdate = CardStackProtocols.CardUpdate
public typealias SwipeAction = CardStackProtocols.SwipeAction
public typealias CardStackConfiguration = CardStackProtocols.CardStackConfiguration

// Swipe Directions
public typealias LeftRight = SwipeDirections.LeftRight
public typealias FourDirections = SwipeDirections.FourDirections
public typealias EightDirections = SwipeDirections.EightDirections

// State Management
public typealias CardStackState = CardStackState

// View Models
public typealias CardStackViewModel = CardStackViewModel

// Data Sources
public typealias StaticCardDataSource = DataSources.StaticCardDataSource
public typealias AsyncSequenceDataSource = DataSources.AsyncSequenceDataSource
public typealias AsyncStreamDataSource = DataSources.AsyncStreamDataSource
public typealias ContinuationDataSource = DataSources.ContinuationDataSource

// Views
public typealias AsyncCardStack = AsyncCardStack