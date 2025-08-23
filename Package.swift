// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "AsyncCardStack",
  platforms: [
    .iOS(.v15),
    .macOS(.v12),
    .tvOS(.v15),
    .watchOS(.v8)
  ],
  products: [
    .library(
      name: "AsyncCardStack",
      targets: ["AsyncCardStack"]
    ),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "AsyncCardStack",
      dependencies: [],
      path: "Sources/AsyncCardStack"
    ),
    .testTarget(
      name: "AsyncCardStackTests",
      dependencies: ["AsyncCardStack"],
      path: "Tests/AsyncCardStackTests"
    ),
  ]
)