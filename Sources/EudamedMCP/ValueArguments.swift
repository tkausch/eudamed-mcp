import MCP

/// Convenience accessors for reading typed tool-call arguments out of the
/// loosely-typed `[String: Value]?` dictionary the MCP SDK hands us.
extension Dictionary where Key == String, Value == MCP.Value {
    func string(_ key: String) -> String? {
        self[key]?.stringValue
    }

    func double(_ key: String) -> Double? {
        guard let value = self[key] else { return nil }
        return value.doubleValue ?? value.intValue.map(Double.init)
    }

    func int(_ key: String) -> Int? {
        guard let value = self[key] else { return nil }
        return value.intValue ?? value.doubleValue.map(Int.init)
    }
}
