import Foundation
import ApolloCodegenLib
import ArgumentParser

// An outer structure to hold all commands and sub-commands handled by this script.
struct SwiftScript: ParsableCommand {

    static var configuration = CommandConfiguration(
            abstract: """
        A swift-based utility for performing Apollo-related tasks.
        
        NOTE: If running from a compiled binary, prefix subcommands with `swift-script`. Otherwise use `swift run ApolloCodegen [subcommand]`.
        """,
            subcommands: [DownloadSchema.self, GenerateCode.self, DownloadSchemaAndGenerateCode.self])
    
    /// The sub-command to download a schema from a provided endpoint.
    struct DownloadSchema: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "downloadSchema",
            abstract: "Downloads the schema with the settings you've set up in the `DownloadSchema` command in `main.swift`.")
        
        func run() throws {
            let fileStructure = try FileStructure()
            CodegenLogger.log("File structure: \(fileStructure)")
            
            // Set up the URL you want to use to download the project
            let endpoint = URL(string: ProcessInfo.processInfo.environment["API_BASE_URL"]!)!
            
            // Calculate where you want to create the folder where the schema will be downloaded by the ApolloCodegenLib framework.
            let schemaPath = try fileStructure.sourceRootURL
                .apollo.childFolderURL(folderName: "LucraSports").apollo.childFileURL(fileName: ProcessInfo.processInfo.environment["APOLLO_SCHEMA_PATH"]!)

            let outputFolder = schemaPath.deletingLastPathComponent()
            let filename = schemaPath.lastPathComponent

            let headers: [ApolloSchemaDownloadConfiguration.HTTPHeader] = [ApolloSchemaDownloadConfiguration.HTTPHeader(key: "X-Hasura-Admin-Secret", value: ProcessInfo.processInfo.environment["HASURA_ADMIN_SECRET"]!)]

            // Create a configuration object for downloading the schema. Provided code will download the schema via an introspection query to the provided URL as SDL (GraphQL Schema Definition Language) to a file called "schema.graphqls". For all configuration parameters check out https://www.apollographql.com/docs/ios/api/ApolloCodegenLib/structs/ApolloSchemaDownloadConfiguration/
            let schemaDownloadOptions = ApolloSchemaDownloadConfiguration(
                using: .introspection(endpointURL: endpoint),
                timeout: 30,
                headers: headers,
                outputFolderURL: outputFolder, schemaFilename: filename
            )
            
            // Actually attempt to download the schema.
            try ApolloSchemaDownloader.fetch(with: schemaDownloadOptions)
        }
    }
    
    /// The sub-command to actually generate code.
    struct GenerateCode: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "generate",
            abstract: "Generates swift code from your schema + your operations based on information set up in the `GenerateCode` command.")
        
        func run() throws {
            let fileStructure = try FileStructure()
            CodegenLogger.log("File structure: \(fileStructure)")
            
            // Get the root of the target for which you want to generate code.
            let targetRootURL = fileStructure.sourceRootURL
                .apollo.childFolderURL(folderName: "LucraSports")

            let schemaPath = try targetRootURL.apollo.childFileURL(fileName: "\(ProcessInfo.processInfo.environment["APOLLO_SCHEMA_PATH"]!).graphqls")

            let outputPath = fileStructure.sourceRootURL
                .apollo.childFolderURL(folderName: "GeneratedAPI/Operations")

            // Make sure the folder exists before trying to generate code.
            try FileManager.default.apollo.createFolderIfNeeded(at: targetRootURL)

            // Create the Codegen options object. This default setup assumes `schema.graphqls` is in the target root folder, all queries are in some kind of subfolder of the target folder and will output as a single file to `API.swift` in the target folder. For alternate setup options, check out https://www.apollographql.com/docs/ios/api/ApolloCodegenLib/structs/ApolloCodegenOptions/
            let codegenOptions = ApolloCodegenOptions(
                outputFormat: .multipleFiles(inFolderAtURL: outputPath),
                customScalarFormat: .passthrough,
                urlToSchemaFile: schemaPath
            )

            // Actually attempt to generate code.
            try ApolloCodegen.run(from: targetRootURL,
                                  with: fileStructure.cliFolderURL,
                                  options: codegenOptions)
        }
    }

    /// A sub-command which lets you download the schema then generate swift code.
    ///
    /// NOTE: This will both take significantly longer than code generation alone and fail when you're offline, so this is not recommended for use in a Run Phase Build script that runs with every build of your project.
    struct DownloadSchemaAndGenerateCode: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "all",
            abstract: "Downloads the schema and generates swift code. NOTE: Not recommended for use as part of a Run Phase Build Script.")

        func run() throws {
            try DownloadSchema().run()
            try GenerateCode().run()
        }
    }
}

// This will set up the command and parse the arguments when this executable is run.
SwiftScript.main()
