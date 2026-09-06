import MCP

/// Small helpers for building JSON Schema `Value` trees for tool `inputSchema`s.
enum Schema {
    static func object(_ properties: [String: Value], required: [String] = []) -> Value {
        var fields: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties),
        ]
        if !required.isEmpty {
            fields["required"] = .array(required.map { .string($0) })
        }
        return .object(fields)
    }

    static func string(_ description: String) -> Value {
        .object(["type": .string("string"), "description": .string(description)])
    }

    static func number(_ description: String) -> Value {
        .object(["type": .string("number"), "description": .string(description)])
    }
}
