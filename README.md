# AsyncCardStack

A modern, flexible SwiftUI card stack library built with Swift concurrency (async/await) and clean architecture principles. This library provides a highly customizable card swiping interface that automatically updates based on data changes.

## Features

- ✨ **Swift Concurrency**: Built entirely with async/await, AsyncStream, and continuations
- 🏗️ **Clean Architecture**: Follows SOLID principles with clear separation of concerns
- 🔄 **Reactive Updates**: Automatically updates when data source changes
- 🎯 **Type-Safe**: Generic implementation with strong type safety
- 🎨 **Customizable**: Flexible configuration and appearance options
- ↩️ **Undo Support**: Built-in undo functionality for swipe actions
- 📱 **Platform Support**: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AsyncCardStack.git", from: "1.0.0")
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

### Firebase Integration Example

```swift
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
        // Load initial cards from Firestore
        let snapshot = try await Firestore.firestore()
            .collection("cards")
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: MyCard.self)
        }
    }
    
    func reportSwipe(card: MyCard, direction: any SwipeDirection) async throws {
        // Report swipe to backend
        try await Firestore.firestore()
            .collection("swipes")
            .addDocument(data: [
                "cardId": card.id,
                "direction": String(describing: direction),
                "timestamp": FieldValue.serverTimestamp()
            ])
    }
    
    func reportUndo(card: MyCard) async throws {
        // Handle undo logic
    }
    
    func loadMoreCards() async throws -> [MyCard] {
        // Load more cards if needed
        return []
    }
}
```

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

### Configuration Options

```swift
let configuration = CardStackConfiguration(
    maxVisibleCards: 5,        // Number of cards visible in stack
    swipeThreshold: 0.5,       // Swipe distance threshold (0.0 - 1.0)
    cardOffset: 10,            // Vertical offset between stacked cards
    cardScale: 0.1,            // Scale factor for cards in stack
    animationDuration: 0.3,    // Animation duration in seconds
    enableUndo: true,          // Enable undo functionality
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