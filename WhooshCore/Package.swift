// swift-tools-version: 6.0
import PackageDescription

// Platform-independent core of Whoosh (PROTOTYPE_PLAN §4.4): no AppKit or
// ScreenCaptureKit, so its tests run against the fake provider with an
// injectable clock.
let package = Package(
    name: "WhooshCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "WhooshCore", targets: ["WhooshCore"]),
    ],
    targets: [
        .target(name: "WhooshCore"),
        .testTarget(name: "WhooshCoreTests", dependencies: ["WhooshCore"]),
    ]
)
