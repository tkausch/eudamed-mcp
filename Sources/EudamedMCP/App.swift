import Foundation
import Logging
import MCP

@main
struct EudamedMCPApp {
    static func main() async throws {
        // The stdio transport speaks JSON-RPC over stdout, so any logging must
        // go to stderr to avoid corrupting the protocol stream.
        LoggingSystem.bootstrap { label in StreamLogHandler.standardError(label: label) }

        let tools: EudamedTools
        do {
            tools = try EudamedTools()
        } catch {
            FileHandle.standardError.write(Data("Failed to initialize EUDAMED client: \(error)\n".utf8))
            exit(1)
        }

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

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
