// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ClotheslineApp",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ClotheslineApp", targets: ["ClotheslineApp"])],
    targets: [
        .executableTarget(name: "ClotheslineApp"),
        .testTarget(name: "ClotheslineAppTests", dependencies: ["ClotheslineApp"])
    ]
)
