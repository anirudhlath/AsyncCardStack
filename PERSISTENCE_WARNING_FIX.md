# AsyncCardStack Persistence Warning Fix

## Problem
The library was showing false warnings about persistence not being available even when card types DID conform to Codable. This was due to having two separate initializers for `UndoConfiguration` - one for Codable types and one for non-Codable types. Swift would choose the non-Codable initializer by default, causing `isPersistenceAvailable` to be false and triggering incorrect warnings.

## Solution
Redesigned the `UndoConfiguration` to have a single initializer that:
1. Works for all types (both Codable and non-Codable)
2. Uses runtime type checking to determine if persistence is actually possible
3. Only shows warnings when persistence is explicitly requested (via `persistenceKey`) but the types don't support it

## Key Changes

### 1. Single Initializer in UndoConfiguration
```swift
public init(
  limit: Int = 5,
  replacementStrategy: CollectionReplacementStrategy = .clearTombstones,
  restoreOnLaunch: RestoreOnLaunchStrategy = .restore,
  persistenceKey: String? = "AsyncCardStack.Tombstones",  // nil disables persistence
  onEviction: (@Sendable (Element, Direction) async -> Void)? = nil,
  onUndoValidation: (@Sendable (Element) async -> Bool)? = nil,
  onConfirmReplacement: (@Sendable () async -> Bool)? = nil
)
```

### 2. Runtime Type Checking in CardStackState
```swift
private var canPersist: Bool {
  let elementIsCodable = Element.self is any Codable.Type
  let directionIsCodable = Direction.self is any Codable.Type
  return elementIsCodable && directionIsCodable
}
```

### 3. Smart Warning Logic
The warning now only shows when ALL of these conditions are met:
- Persistence is requested (`persistenceKey` is not nil)
- Types don't support Codable (checked at runtime)
- There are tombstones to persist
- Running in DEBUG mode
- Warning hasn't been shown yet for this instance

## Usage Examples

### Codable Types (No Warning)
```swift
struct MyCard: CardElement, Codable {
  let id: String
  let title: String
}

// No warning - types support persistence
let config = UndoConfiguration<MyCard, LeftRight>(
  persistenceKey: "MyApp.Undo"
)
```

### Non-Codable Types with Persistence (Shows Warning)
```swift
struct MyCard: CardElement {
  let id: String
  let action: () -> Void  // Can't be Codable
}

// Warning shown - persistence requested but not possible
let config = UndoConfiguration<MyCard, LeftRight>(
  persistenceKey: "MyApp.Undo"
)
```

### Non-Codable Types without Persistence (No Warning)
```swift
struct MyCard: CardElement {
  let id: String
  let action: () -> Void
}

// No warning - persistence not requested
let config = UndoConfiguration<MyCard, LeftRight>(
  persistenceKey: nil  // Explicitly disabled
)

// Or use convenience initializer
let config = UndoConfiguration<MyCard, LeftRight>.withoutPersistence
```

## Testing
Created comprehensive tests in `PersistenceWarningTests.swift` that verify:
- No warnings for Codable types
- Warnings shown for non-Codable types when persistence is requested
- No warnings when persistence is disabled
- Warning only shown once per instance

All tests pass successfully ✅