import Foundation

enum JSONText {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    /// Encodes a value to a pretty-printed JSON string, or a `{"error": ...}`
    /// JSON string describing the encoding failure.
    static func encode<T: Encodable>(_ value: T) -> String {
        do {
            let data = try encoder.encode(value)
            return String(decoding: data, as: UTF8.self)
        } catch {
            return #"{"error": "failed to encode result: \#(error)"}"#
        }
    }
}
