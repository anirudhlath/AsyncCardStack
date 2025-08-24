# Building AsyncCardStack

## Prerequisites
- Xcode 15.0 or later
- Swift 5.9 or later
- iOS 15.0+ deployment target

## Build Methods

### Method 1: Swift Package Manager (Command Line)
```bash
# Navigate to the package directory
cd /Users/anirudhlath/code/relerlabs/AsyncCardStack

# Build for iOS Simulator
swift build -Xswiftc -sdk -Xswiftc $(xcrun --sdk iphonesimulator --show-sdk-path) \
            -Xswiftc -target -Xswiftc arm64-apple-ios15.0-simulator

# Build for macOS (if needed)
swift build

# Run tests
swift test
```

### Method 2: Xcode Build
```bash
# Build for iOS Simulator using xcodebuild
xcodebuild -scheme AsyncCardStack \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build

# Build for specific configuration
xcodebuild -scheme AsyncCardStack \
           -configuration Debug \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build
```

### Method 3: Open in Xcode
1. Open Xcode
2. File → Open → Navigate to `/Users/anirudhlath/code/relerlabs/AsyncCardStack`
3. Select the `Package.swift` file
4. Choose your target device/simulator
5. Press Cmd+B to build

## Integration into Your Project

### As a Local Package
1. In your Xcode project, go to File → Add Package Dependencies
2. Click "Add Local..."
3. Navigate to `/Users/anirudhlath/code/relerlabs/AsyncCardStack`
4. Click "Add Package"

### As a Swift Package Dependency
Add to your `Package.swift`:
```swift
dependencies: [
    .package(path: "../AsyncCardStack")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the local file URL: `file:///Users/anirudhlath/code/relerlabs/AsyncCardStack`

## Known Issues

### Swift 6 Concurrency Warnings
The library currently shows some Swift 6 concurrency warnings related to Sendable conformance. These are warnings, not errors, and don't affect functionality. They will be addressed in a future update.

### Test Target Warning
You may see a warning about test target location. This is cosmetic and doesn't affect the build.

## Troubleshooting

### If build fails with module errors:
```bash
# Clean build folder
rm -rf .build
rm -rf .swiftpm

# Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/AsyncCardStack-*

# Rebuild
swift build
```

### If Xcode can't resolve the package:
1. File → Packages → Reset Package Caches
2. Clean Build Folder (Cmd+Shift+K)
3. Rebuild (Cmd+B)

## Example App

To run the example app:
1. Open `Example/ExampleApp.swift` in Xcode
2. Create a new iOS app target if needed
3. Import AsyncCardStack
4. Run the app

## Quick Test

To quickly verify the library builds:
```bash
# This will compile the library and show any errors
swift build --product AsyncCardStack
```

## Output Location

Built products are located at:
- Command line: `.build/debug/` or `.build/release/`
- Xcode: `~/Library/Developer/Xcode/DerivedData/AsyncCardStack-*/Build/Products/`