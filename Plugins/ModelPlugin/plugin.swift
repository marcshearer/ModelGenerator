import PackagePlugin
import Foundation

@main
struct ModelPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }
        
        let generatorTool = try context.tool(named: "ModelGenerator")
        // Changed from "csv" to "modeldef"
        let inputFiles: [URL] = sourceTarget.sourceFiles(withSuffix: "modeldef").map { $0.url }
        
        return makeCommands(
            generatorTool: generatorTool.url,
            inputPaths: inputFiles,
            workDirectory: context.pluginWorkDirectoryURL)
    }
}

// MARK: - Xcode Project Support
#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension ModelPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        
        let generatorTool = try context.tool(named: "ModelGenerator")
        let inputFiles: [URL] = target.inputFiles.filter { $0.url.pathExtension.lowercased() == "modeldef" }
            .map{$0.url}
        
        return makeCommands(
            generatorTool: generatorTool.url,
            inputPaths: inputFiles,
            workDirectory: context.pluginWorkDirectoryURL
        )
    }
}
#endif

// MARK: - Shared Command Builder
private extension ModelPlugin {
    func makeCommands(generatorTool: URL, inputPaths: [URL], workDirectory: URL) -> [Command] {
        guard !inputPaths.isEmpty else { return [] }
        var commands: [Command] = inputPaths.map { inputPath in
            let baseName = inputPath.deletingPathExtension().lastPathComponent
            let outputPath = workDirectory.appending(path: "\(baseName).generated.swift")

            return .buildCommand(
                displayName: "Generating Swift model from \(inputPath.lastPathComponent)",
                executable: generatorTool,
                arguments: [
                    inputPath.path,
                    outputPath.path
                ],
                inputFiles: [inputPath],
                outputFiles: [outputPath]
            )
        }

        let manifestOutput = workDirectory.appending(path: "AllEntities.generated.swift")
        let sortedInputs = inputPaths.sorted { $0.lastPathComponent < $1.lastPathComponent }

        commands.append(
            .buildCommand(
                displayName: "Generating AllEntities manifest",
                executable: generatorTool,
                arguments: ["--manifest", manifestOutput.path] + sortedInputs.map(\.path),
                inputFiles: sortedInputs,
                outputFiles: [manifestOutput]
            )
        )

        return commands
    }
}
