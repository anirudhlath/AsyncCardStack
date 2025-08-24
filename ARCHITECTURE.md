# AsyncCardStack Architecture

## Overview

AsyncCardStack is a modern SwiftUI card stack library built with Swift concurrency (async/await) and clean architecture principles. It provides a flexible, reactive card swiping interface that automatically updates based on data changes.

## Architecture Principles

### 1. Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Views: AsyncCardStack, CardView                │    │
│  │  ViewModels: CardStackViewModel                 │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────┐
│                      Domain Layer                        │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Protocols: CardElement, SwipeDirection, etc    │    │
│  │  Models: CardStackState, SwipeAction            │    │
│  │  Use Cases: Swipe handling, Undo logic          │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                    │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Services: DataSource implementations           │    │
│  │  Extensions: Helper utilities                   │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 2. SOLID Principles

- **Single Responsibility**: Each component has one clear purpose
- **Open/Closed**: Extensible through protocols, not modification
- **Liskov Substitution**: All DataSource implementations are interchangeable
- **Interface Segregation**: Small, focused protocols
- **Dependency Inversion**: Depend on abstractions (protocols), not concrete types

### 3. Swift Concurrency

- **async/await**: All asynchronous operations use modern Swift concurrency
- **AsyncStream**: Real-time data updates through AsyncStream
- **Continuation**: Manual control over stream updates
- **Actors**: Thread-safe state management with @MainActor
- **Structured Concurrency**: Proper task cancellation and lifecycle

## Core Components

### Domain Layer

#### Protocols

```swift
protocol CardElement: Identifiable, Equatable, Sendable
protocol SwipeDirection: Equatable, CaseIterable, Sendable
protocol CardDataSource: Sendable
```

#### Models

- `CardStackState`: Manages the current state of cards
- `SwipeAction`: Represents a swipe action with direction and timestamp
- `CardUpdate`: Enum representing different types of card updates

### Presentation Layer

#### CardStackViewModel

Central coordinator that:
- Manages card state through `CardStackState`
- Listens to data source updates via AsyncStream
- Handles swipe and undo actions
- Triggers loading of additional cards
- Provides callbacks for custom validation

#### AsyncCardStack View

Main SwiftUI view that:
- Renders visible cards in a stack
- Manages drag gestures and animations
- Coordinates with ViewModel for state updates
- Provides customizable card content

#### CardView

Individual card view that:
- Handles drag gestures
- Calculates swipe direction
- Manages card animations
- Reports swipe actions to parent

### Infrastructure Layer

#### Data Sources

Multiple implementations for different use cases:

1. **StaticCardDataSource**: For static arrays of cards
2. **AsyncSequenceDataSource**: Wraps any AsyncSequence
3. **AsyncStreamDataSource**: Direct AsyncStream integration
4. **ContinuationDataSource**: Manual control via continuation

## Data Flow

### 1. Initial Load

```
DataSource.loadInitialCards()
    ↓
CardStackViewModel receives cards
    ↓
Updates CardStackState
    ↓
AsyncCardStack renders cards
```

### 2. Real-time Updates

```
External data change (e.g., Firebase)
    ↓
DataSource.cardStream yields update
    ↓
CardStackViewModel processes update
    ↓
Updates CardStackState
    ↓
AsyncCardStack automatically re-renders
```

### 3. Swipe Action

```
User swipes card
    ↓
CardView detects gesture
    ↓
Calls ViewModel.swipe()
    ↓
Updates CardStackState
    ↓
Reports to DataSource
    ↓
Triggers preload if needed
```

## Key Features

### Automatic Updates

The library automatically updates the UI when:
- New cards are added to the data source
- Cards are removed or filtered
- Card data is updated
- The data source is replaced entirely

### Flexible Data Sources

Support for multiple data source types:
- Static arrays
- Firebase Firestore collections
- Any AsyncSequence
- Custom AsyncStream implementations

### Advanced Undo Support with Persistence

The library provides sophisticated undo functionality with immutable ID tracking and optional persistence:

#### Core Mechanism
- **Immutable ID Tracking**: Uses stable card IDs instead of array indices
- **Tombstone Pattern**: Maintains recently swiped cards in memory
- **Bounded History**: Configurable limit on undo history to control memory
- **Deferred Deletion**: Cards are only deleted after exiting the undo window
- **Local Persistence**: Optional persistence of undo history across app restarts

#### Configuration
Undo is optional and configured through `UndoConfiguration`:
```swift
UndoConfiguration(
    limit: 5,                              // Max undoable cards
    replacementStrategy: .clearTombstones, // How to handle collection replacement
    restoreOnLaunch: .clearGracefully,     // Persistence behavior
    persistenceKey: "MyApp.UndoHistory",   // UserDefaults key for persistence
    onEviction: { card, direction in       // Called when card exits undo window
        // Perfect for backend deletion
        try await deleteFromBackend(card)
    }
)
```

#### Collection Replacement Strategies
When the entire card collection is replaced (e.g., filter changes):
- **`.clearTombstones`**: Clear undo history (safest, default)
- **`.preserveValidTombstones`**: Keep cards that exist in new collection
- **`.blockIfTombstones`**: Prevent replacement if undo history exists
- **`.askUser`**: Show confirmation dialog before clearing history

#### Restore on Launch Strategies
Control how undo history behaves after app restart:
- **`.restore`**: Keep undo history across app restarts
- **`.clearGracefully`**: Restore tombstones but immediately evict them (triggers backend deletion)
- **`.ignore`**: Start fresh, don't restore history

#### How It Works
1. Swiped cards are added to a tombstone list
2. Cards remain in memory until limit is reached
3. When limit exceeded, oldest card is evicted and deletion callback triggered
4. Undo restores card from tombstone list
5. Position tracking uses immutable IDs, preventing index corruption
6. If persistence is enabled, tombstones are saved to UserDefaults
7. On app launch, tombstones are restored based on the configured strategy

#### Solving the Persistence Edge Case
The persistence feature solves a critical edge case:
- **Problem**: User swipes cards → App terminates → Cards never deleted from backend → Cards reappear on restart
- **Solution**: `.clearGracefully` strategy restores tombstones and immediately evicts them, ensuring backend deletion

### Preloading

Automatic preloading of cards:
- Configurable threshold
- Triggers when remaining cards drop below threshold
- Non-blocking async operation

## Usage Patterns

### Basic Static Cards

```swift
let viewModel = CardStackViewModel(cards: staticArray)
AsyncCardStack(viewModel: viewModel) { card, direction in
    CardContentView(card: card)
}
```

### Firebase Integration

```swift
let dataSource = FirebaseCardDataSource(collection: "cards")
let viewModel = CardStackViewModel(dataSource: dataSource)
AsyncCardStack(viewModel: viewModel) { card, direction in
    CardContentView(card: card)
}
```

### Custom Stream

```swift
let stream = AsyncStream<CardUpdate<Card>> { continuation in
    // Setup listeners
    continuation.yield(.initial(cards))
}
let dataSource = AsyncStreamDataSource(stream: stream)
```

## Performance Considerations

1. **Lazy Rendering**: Only visible cards are rendered
2. **Efficient Updates**: Minimal re-renders through @Published
3. **Async Operations**: Non-blocking data loading
4. **Memory Management**: Proper cleanup with task cancellation
5. **Animation Performance**: Hardware-accelerated SwiftUI animations

## Testing Strategy

The architecture supports comprehensive testing:

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test data flow between layers
3. **UI Tests**: Test gesture handling and animations
4. **Mock Data Sources**: Easy testing with mock implementations

## Future Enhancements

Potential areas for extension:
1. Custom gesture recognizers
2. Advanced animation curves
3. Multi-directional swipe support (already partially implemented)
4. Accessibility improvements
5. Performance optimizations for large datasets