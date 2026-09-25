// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "Cove", platforms: [.macOS(.v14)], products: [.executable(name: "Cove", targets: ["Cove"])],
  dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
  targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "CoveCore", dependencies: ["CSQLite"]),
    .executableTarget(name: "Cove", dependencies: ["CoveCore", .product(name: "Sparkle", package: "Sparkle")],
      resources: [.process("Resources")],
      linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
    .testTarget(name: "CoveCoreTests", dependencies: ["CoveCore"]),
    .testTarget(name: "CoveRenderingTests", dependencies: ["Cove", "CoveCore"]),
  ])
