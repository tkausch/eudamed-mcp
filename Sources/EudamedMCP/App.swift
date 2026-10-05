import Foundation
import Logging
import MCP

@main
struct EudamedMCPApp {
    static func main() async throws {
        // `eudamed-mcp serve [--hostname H] [--port P]` runs the Streamable HTTP
        // server; any other invocation speaks MCP over stdio.
        let httpMode = CommandLine.arguments.dropFirst().first == "serve"

        if !httpMode {
            // The stdio transport speaks JSON-RPC over stdout, so any logging must
            // go to stderr to avoid corrupting the protocol stream.
            LoggingSystem.bootstrap { label in StreamLogHandler.standardError(label: label) }
        }

        let tools: EudamedTools
        do {
            tools = try EudamedTools()
        } catch {
            FileHandle.standardError.write(Data("Failed to initialize EUDAMED client: \(error)\n".utf8))
            exit(1)
        }

        if httpMode {
            try await HTTPServer.run(tools: tools)
        } else {
            let server = await makeServer(tools: tools)
            try await server.start(transport: StdioTransport())
            await server.waitUntilCompleted()
        }
    }

    /// Creates an MCP server with the EUDAMED tools registered.
    static func makeServer(tools: EudamedTools) async -> Server {
        let server = Server(
            name: "eudamed-mcp",
            version: "0.1.0",
            instructions: """
                Provides read-only access to the EUDAMED public API: search and look up \
                economic operators (actors), UDI device records, and reference/nomenclature \
                data used by the EU medical device and IVD registration system.
                """,
            capabilities: .init(tools: .init(listChanged: false))
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: EudamedTools.definitions)
        }

        await server.withMethodHandler(CallTool.self) { params in
            await tools.call(params)
        }

        return server
    }
}
