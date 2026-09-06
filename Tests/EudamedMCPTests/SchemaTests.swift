import MCP
import XCTest

@testable import EudamedMCP

final class SchemaTests: XCTestCase {
    func testObjectSchemaIncludesRequiredFields() {
        let schema = Schema.object(
            ["name": Schema.string("A name")],
            required: ["name"]
        )
        guard case .object(let fields) = schema else {
            return XCTFail("expected an object schema")
        }
        XCTAssertEqual(fields["type"], .string("object"))
        XCTAssertEqual(fields["required"], .array([.string("name")]))
    }

    func testObjectSchemaOmitsRequiredWhenEmpty() {
        let schema = Schema.object(["name": Schema.string("A name")])
        guard case .object(let fields) = schema else {
            return XCTFail("expected an object schema")
        }
        XCTAssertNil(fields["required"])
    }

    func testToolDefinitionsHaveUniqueNames() {
        let names = EudamedTools.definitions.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }
}
