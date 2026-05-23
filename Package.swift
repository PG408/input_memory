// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "InputMemory",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "InputMemoryCore", targets: ["InputMemoryCore"]),
        .executable(name: "InputMemory", targets: ["InputMemory"]),
        .executable(name: "InputMemorySelfTest", targets: ["InputMemorySelfTest"])
    ],
    targets: [
        .target(
            name: "InputMemoryCore",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "InputMemory",
            dependencies: ["InputMemoryCore"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "InputMemorySelfTest",
            dependencies: ["InputMemoryCore"]
        )
    ]
)
