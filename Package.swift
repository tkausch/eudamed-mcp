// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "eudamed-mcp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "eudamed-mcp",
            targets: ["EudamedMCP"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/tkausch/eudamed-public", from: "1.0.20"),
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.12.1"),
        .package(url: "https://github.com/vapor/vapor", from: "4.115.0"),
    ],
    targets: [
        .executableTarget(
            name: "EudamedMCP",
            dependencies: [
                .product(name: "EudamedClient", package: "eudamed-public"),
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "EudamedMCPTests",
            dependencies: ["EudamedMCP"]
        ),
    ]
)
