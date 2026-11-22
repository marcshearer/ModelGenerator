// swift-tools-version: 6.4.2

import PackageDescription

let package = Package(
    name: "ModelGenerator",
    platforms: [.macOS(.v26)], // Plugins run on macOS during the build
    products: [
        // Expose the plugin so any external project can apply it
        .plugin(
            name: "ModelPlugin",
            targets: ["ModelPlugin"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ModelGenerator"
        ),
        .plugin(
            name: "ModelPlugin",
            capability: .buildTool(),
            dependencies: ["ModelGenerator"]
        )
    ]
)
