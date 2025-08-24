# AsyncCardStack

A modern, flexible SwiftUI card stack library built with Swift concurrency (async/await) and clean architecture principles. This library provides a highly customizable card swiping interface that automatically updates based on data changes.

## Features

- ✨ **Swift Concurrency**: Built entirely with async/await, AsyncStream, and continuations (no Combine)
- 🏗️ **Clean Architecture**: Follows SOLID principles with clear separation of concerns
- 🔄 **Reactive Updates**: Automatically updates when data source changes
- 🎯 **Type-Safe**: Generic implementation with strong type safety
- 🎨 **Customizable**: Flexible configuration and appearance options
- ↩️ **Advanced Undo**: Sophisticated undo with tombstone pattern and immutable ID tracking
- 💾 **Persistence**: Optional local persistence of undo history across app restarts
- 📱 **Platform Support**: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/anirudhlath/AsyncCardStack.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL

## Usage

### Basic Example

```swift
import AsyncCardStack
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CardStackViewModel(
        cards: [
            MyCard(id: "1", title: "Card 1"),
            MyCard(id: "2", title: "Card 2"),
            MyCard(id: "3", title: "Card 3")
        ]
    )
    
    var body: some View {
        AsyncCardStack(
            viewModel: viewModel,
            configuration: .default
        ) { card, direction in
            // Your card content view
            CardContentView(card: card, swipeDirection: direction)
        }
    }
}

struct MyCard: CardElement {
    let id: String
    let title: String
}
```

### Using with AsyncStream

```swift
// Create a continuation-based data source
let dataSource = ContinuationDataSource<MyCard>()

// Create view model with the data source
let viewModel = CardStackViewModel(
    dataSource: dataSource,
    configuration: CardStackConfiguration(
        maxVisibleCards: 5,
        swipeThreshold: 0.3,
        enableUndo: true
    )
)

// Update cards dynamically
dataSource.sendInitialCards(initialCards)
dataSource.appendCards(moreCards)
dataSource.replaceCards(filteredCards)
```

### Complete Firebase Integration with Persistence

```swift
// 1. Define your card model
struct MyCard: CardElement, Codable {
    let id: String
    let title: String
    let imageURL: String
}

// 2. Create Firebase data source
class FirebaseCardDataSource: CardDataSource {
    typealias Element = MyCard
    
    private var listener: ListenerRegistration?
    private var continuation: AsyncStream<CardUpdate<MyCard>>.Continuation?
    
    var cardStream: AsyncStream<CardUpdate<MyCard>> {
        get async throws {
            AsyncStream { continuation in
                self.continuation = continuation
                
                // Listen to Firestore collection
                listener = Firestore.firestore()
                    .collection("cards")
                    .addSnapshotListener { snapshot, error in
                        guard let documents = snapshot?.documents else { return }
                        
                        let cards = documents.compactMap { doc in
                            try? doc.data(as: MyCard.self)
                        }
                        
                        continuation.yield(.replace(cards))
                    }
            }
        }
    }
    
    func loadInitialCards() async throws -> [MyCard] {
        let snapshot = try await Firestore.firestore()
            .collection("cards")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: MyCard.self)
        }
    }
    
    func reportSwipe(card: MyCard, direction: any SwipeDirection) async throws {
        // Report swipe but DON'T delete yet (undo window)
        try await Firestore.firestore()
            .collection("swipes")
            .addDocument(data: [
                "cardId": card.id,
                "direction": String(describing: direction),
                "timestamp": FieldValue.serverTimestamp()
            ])
    }
    
    func reportUndo(card: MyCard) async throws {
        // Remove the swipe record
        let swipes = try await Firestore.firestore()
            .collection("swipes")
            .whereField("cardId", isEqualTo: card.id)
            .getDocuments()
        
        for doc in swipes.documents {
            try await doc.reference.delete()
        }
    }
    
    func loadMoreCards() async throws -> [MyCard] {
        // Implement pagination if needed
        return []
    }
}

// 3. Configure undo with persistence
let undoConfig = UndoConfiguration<MyCard, LeftRight>(
    limit: 5,
    replacementStrategy: .clearTombstones,
    restoreOnLaunch: .clearGracefully,  // Ensures cleanup on restart
    persistenceKey: "Reler.UndoHistory",
    onEviction: { card, direction in
        // Delete from Firebase when card exits undo window
        try await Firestore.firestore()
            .collection("cards")
            .document(card.id)
            .delete()
    }
)

// 4. Create view model
let dataSource = FirebaseCardDataSource()
let viewModel = CardStackViewModel(
    dataSource: dataSource,
    undoConfiguration: undoConfig
)

// 5. Use in your view
struct ContentView: View {
    @StateObject private var viewModel: CardStackViewModel<MyCard, LeftRight, FirebaseCardDataSource>
    
    var body: some View {
        AsyncCardStack(viewModel: viewModel) { card, direction in
            CardContentView(card: card)
                .overlay(alignment: .topLeading) {
                    if let direction = direction {
                        DirectionLabel(direction: direction)
                    }
                }
        }
        .overlay(alignment: .bottom) {
            Button("Undo") {
                Task {
                    await viewModel.undo()
                }
            }
            .disabled(!viewModel.canUndo)
        }
    }
}
```

This setup ensures:
- ✅ Cards can be undone within the configured limit
- ✅ Cards are deleted from Firebase only after exiting undo window
- ✅ If app crashes, tombstones are restored and properly cleaned up on restart
- ✅ Filter changes are handled gracefully with configurable strategies

### Custom Swipe Directions

```swift
// Use built-in directions
AsyncCardStack<MyCard, LeftRight, StaticCardDataSource<MyCard>, CardView>(
    viewModel: viewModel
) { card, direction in
    CardView(card: card)
}

// Or create custom directions
enum CustomDirection: String, SwipeDirection, CaseIterable {
    case like, dislike, superLike, skip
    
    static func from(angle: Angle) -> Self? {
        // Define your angle mappings
    }
    
    var angle: Angle {
        // Return angle for each direction
    }
}
```

### Undo Configuration

The library provides advanced undo functionality with persistence support:

```swift
let undoConfig = UndoConfiguration<MyCard, LeftRight>(
    limit: 5,                              // Max undoable cards
    replacementStrategy: .clearTombstones, // How to handle filter changes
    restoreOnLaunch: .clearGracefully,     // Persistence behavior
    persistenceKey: "MyApp.UndoHistory",   // UserDefaults key
    onEviction: { card, direction in
        // Called when card exits undo window
        // Perfect for backend deletion
        try await deleteFromBackend(card)
    }
)

let viewModel = CardStackViewModel(
    dataSource: dataSource,
    undoConfiguration: undoConfig
)
```

#### Replacement Strategies
When the card collection is replaced (e.g., filter changes):
- `.clearTombstones` - Clear undo history (default, safest)
- `.preserveValidTombstones` - Keep cards that exist in new collection
- `.blockIfTombstones` - Prevent replacement if undo history exists
- `.askUser` - Show confirmation dialog

#### Restore on Launch Strategies
Control how undo history behaves after app restart:
- `.restore` - Keep undo history across app restarts
- `.clearGracefully` - Restore tombstones but immediately evict them (triggers backend deletion)
- `.ignore` - Start fresh, don't restore history

### Configuration Options

```swift
let configuration = CardStackConfiguration(
    maxVisibleCards: 5,        // Number of cards visible in stack
    swipeThreshold: 0.5,       // Swipe distance threshold (0.0 - 1.0)
    cardOffset: 10,            // Vertical offset between stacked cards
    cardScale: 0.1,            // Scale factor for cards in stack
    animationDuration: 0.3,    // Animation duration in seconds
    preloadThreshold: 3        // When to trigger loading more cards
)
```

### Handling Swipe Events

```swift
let viewModel = CardStackViewModel(dataSource: dataSource)

// Set swipe handler
viewModel.onSwipe = { card, direction in
    // Validate or process swipe
    // Return false to cancel the swipe
    return true
}

// Set undo handler
viewModel.onUndo = { card in
    // Process undo
    // Return false to cancel the undo
    return true
}

// Use in view
AsyncCardStack(
    viewModel: viewModel,
    onChange: { direction in
        // Called when swipe direction changes during drag
        print("Swiping: \(direction)")
    }
) { card, direction in
    CardView(card: card)
}
```

## Architecture

The library follows clean architecture principles:

### Domain Layer
- **Protocols**: Core abstractions (`CardElement`, `SwipeDirection`, `CardDataSource`)
- **Models**: Business entities (`SwipeAction`, `CardUpdate`, `CardStackState`)
- **Use Cases**: Business logic (swipe handling, undo logic)

### Presentation Layer
- **ViewModels**: `CardStackViewModel` manages state and coordinates with data sources
- **Views**: `AsyncCardStack` and `CardView` provide the UI

### Infrastructure Layer
- **Services**: Various `DataSource` implementations
- **Extensions**: Helper extensions and utilities

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Xcode 14.0+
- Swift 5.9+

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
