import Foundation
import MCP
import Vapor

/// Serves the MCP server over Streamable HTTP (stateless mode) using Vapor.
///
/// Every POST to `/mcp` gets its own short-lived `Server` and
/// `StatelessHTTPServerTransport`. All tools are read-only and the server never
/// sends notifications, so there is no session state to keep — and a fresh
/// server per request means any number of clients can each send `initialize`.
///
/// Configuration (environment variables):
/// - `EUDAMED_MCP_TOKEN`: if set, requests must carry `Authorization: Bearer <token>`.
/// - `EUDAMED_MCP_ALLOWED_HOSTS`: comma-separated `Host` header values to accept
///   (e.g. `eudamed.example.com,localhost:*`) as DNS rebinding protection.
///   If unset, `Host`/`Origin` are not validated.
enum HTTPServer {
    static func run(tools: EudamedTools) async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        app.http.server.configuration.hostname = Environment.get("HOST") ?? "127.0.0.1"
        app.http.server.configuration.port = Environment.get("PORT").flatMap(Int.init) ?? 8080

        let token = Environment.get("EUDAMED_MCP_TOKEN").flatMap { $0.isEmpty ? nil : $0 }
        let allowedHostList = Environment.get("EUDAMED_MCP_ALLOWED_HOSTS")?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let allowedHosts = allowedHostList.flatMap { $0.isEmpty ? nil : $0 }

        // Browser-based clients (e.g. MCP Inspector in direct mode) need CORS,
        // including answers to `OPTIONS` preflights. Registered first so that
        // error responses such as 401 also carry CORS headers.
        app.middleware.use(
            CORSMiddleware(configuration: .init(
                allowedOrigin: .all,
                allowedMethods: [.GET, .POST, .DELETE, .OPTIONS],
                allowedHeaders: [
                    .accept, .authorization, .contentType, .origin,
                    "Mcp-Session-Id", "Mcp-Protocol-Version", "Last-Event-ID",
                ],
                exposedHeaders: ["Mcp-Session-Id", "Mcp-Protocol-Version", .wwwAuthenticate]
            )),
            at: .beginning
        )

        app.get("health") { _ in "ok" }

        let mcp = app.grouped(BearerTokenMiddleware(token: token))
        for method: HTTPMethod in [.POST, .GET, .DELETE] {
            mcp.on(method, "mcp", body: .collect(maxSize: "1mb")) { req in
                try await handle(req, tools: tools, allowedHosts: allowedHosts)
            }
        }

        do {
            try await app.execute()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    private static func handle(
        _ req: Vapor.Request,
        tools: EudamedTools,
        allowedHosts: [String]?
    ) async throws -> Vapor.Response {
        let transport = StatelessHTTPServerTransport(
            validationPipeline: StandardValidationPipeline(validators: [
                allowedHosts.map { OriginValidator(allowedHosts: $0, allowedOrigins: []) }
                    ?? .disabled,
                AcceptHeaderValidator(mode: .jsonOnly),
                ContentTypeValidator(),
                ProtocolVersionValidator(),
            ]),
            logger: req.logger
        )
        let server = await EudamedMCPApp.makeServer(tools: tools)
        try await server.start(transport: transport)
        let response = await transport.handleRequest(MCP.HTTPRequest(req))
        await server.stop()
        return Vapor.Response(response)
    }
}

/// Rejects requests without the configured bearer token. A `nil` token disables the check.
private struct BearerTokenMiddleware: AsyncMiddleware {
    let token: String?

    func respond(to request: Vapor.Request, chainingTo next: any AsyncResponder) async throws -> Vapor.Response {
        guard let token else { return try await next.respond(to: request) }
        guard let provided = request.headers.bearerAuthorization?.token,
              constantTimeEquals(provided, token)
        else {
            throw Abort(.unauthorized, headers: ["WWW-Authenticate": "Bearer"])
        }
        return try await next.respond(to: request)
    }

    private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let a = Array(a.utf8), b = Array(b.utf8)
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }
}

// MARK: - Vapor ↔ MCP conversions

private extension MCP.HTTPRequest {
    init(_ req: Vapor.Request) {
        var headers: [String: String] = [:]
        for (name, value) in req.headers {
            headers[name] = headers[name].map { "\($0), \(value)" } ?? value
        }
        self.init(
            method: req.method.rawValue,
            headers: headers,
            body: req.body.data.map { Data($0.readableBytesView) },
            path: req.url.path
        )
    }
}

private extension Vapor.Response {
    convenience init(_ response: MCP.HTTPResponse) {
        var headers = HTTPHeaders()
        for (name, value) in response.headers {
            headers.replaceOrAdd(name: name, value: value)
        }
        self.init(
            status: HTTPResponseStatus(statusCode: response.statusCode),
            headers: headers,
            body: response.bodyData.map { Vapor.Response.Body(data: $0) } ?? .empty
        )
    }
}
