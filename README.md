# eudamed-mcp

A Model Context Protocol (MCP) server that exposes the [EUDAMED public API](https://github.com/tkausch/eudamed-public)
— the EU's medical device and in vitro diagnostic device registration
database — to MCP clients (Claude Desktop, Claude Code, etc.) over stdio.

It wraps [`eudamed-public`](https://github.com/tkausch/eudamed-public)'s
`EudamedClient` library, which already handles pagination, retries, and
resolving numeric ids to human-readable reference labels.

## Tools

| Tool | Description |
|---|---|
| `search_actors` | Search economic operators (manufacturers, authorised representatives, importers, competent authorities) by name, type, or country. |
| `get_actor` | Look up a single actor by its exact EUDAMED actor id (UUID). |
| `search_udi_devices` | Search UDI device records by identifiers, names, manufacturer, risk class, or legislation. |
| `get_udi_device` | Look up a single UDI device record by its exact Primary DI. |
| `search_reference_data` | Search reference/nomenclature lookup tables (risk classes, legislations, statuses, ...). |
| `get_reference_value` | Resolve a single reference value by numeric id, code, and language. |

All read-only; the EUDAMED public API has no write operations and requires
no authentication.

## Build

```sh
swift build -c release
```

The binary is produced at `.build/release/eudamed-mcp`.

## Run standalone

The server speaks MCP over stdio: JSON-RPC messages in on stdin, one per
line, and responses out on stdout, one per line. All logging goes to
stderr so it never corrupts the protocol stream.

```sh
.build/release/eudamed-mcp
```

## Configure in an MCP client

For Claude Desktop / Claude Code, add to your MCP server config:

```json
{
  "mcpServers": {
    "eudamed": {
      "command": "/absolute/path/to/eudamed-mcp/.build/release/eudamed-mcp"
    }
  }
}
```

## Development

```sh
swift build
swift test
```

## License

Licensed under [PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0) —
see `LICENSE`. It depends on
[`eudamed-public`](https://github.com/tkausch/eudamed-public), which is
licensed under the same terms; see that project's `EULA.md` for commercial
licensing options.
