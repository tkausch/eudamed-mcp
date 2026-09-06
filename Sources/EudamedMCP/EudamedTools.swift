import EudamedClient
import MCP

/// Registers and dispatches the MCP tools that expose the EUDAMED public API
/// (actors, UDI devices, and reference data) over stdio.
struct EudamedTools {
    private let actors: RemoteActorRepository
    private let devices: RemoteUdiDevicesRepository
    private let references: RemoteReferenceRepository

    init() throws {
        actors = try RemoteActorRepository()
        devices = try RemoteUdiDevicesRepository()
        references = try RemoteReferenceRepository()
    }

    // MARK: - Tool list

    static let definitions: [Tool] = [
        Tool(
            name: "search_actors",
            description: """
                Search economic operators (manufacturers, authorised representatives, \
                importers, competent authorities, etc.) registered in EUDAMED. All \
                filters are optional and combined with AND; omit all of them to list \
                actors. Automatically follows pagination and returns every match.
                """,
            inputSchema: Schema.object([
                "actorId": Schema.string("Exact EUDAMED actor identifier (UUID)."),
                "name": Schema.string("(Partial) registered name of the actor."),
                "abbreviatedName": Schema.string("(Partial) abbreviated/short name of the actor."),
                "actorType": Schema.string(
                    "Actor type, e.g. manufacturer, authorised-representative, importer, competent-authority."
                ),
                "countryIso2Code": Schema.string("ISO 3166-1 alpha-2 country code, e.g. DE, FR, IT."),
            ])
        ),
        Tool(
            name: "get_actor",
            description: "Look up a single EUDAMED actor by its exact actor identifier (UUID).",
            inputSchema: Schema.object(
                ["actorId": Schema.string("The EUDAMED actor identifier (UUID) to look up.")],
                required: ["actorId"]
            )
        ),
        Tool(
            name: "search_udi_devices",
            description: """
                Search UDI (Unique Device Identification) device records in EUDAMED by \
                identifiers, names, manufacturer, risk classification, or legislation. \
                All filters are optional and combined with AND. Automatically follows \
                pagination and returns every match, with resolved human-readable labels \
                for risk class, legislation, status, and market status.
                """,
            inputSchema: Schema.object([
                "primaryDi": Schema.string("Primary Device Identifier (Primary DI)."),
                "basicUdi": Schema.string("Basic UDI-DI shared across all versions/packaging of the device."),
                "tradeName": Schema.string("Trade/brand name of the device."),
                "deviceName": Schema.string("Name of the device."),
                "deviceModel": Schema.string("Model designation of the device."),
                "reference": Schema.string("Manufacturer's reference/catalogue number."),
                "nomenclatureCode": Schema.string(
                    "CND or GMDN nomenclature code (applied as a client-side filter)."
                ),
                "riskClassId": Schema.number(
                    "Numeric risk class id (see search_reference_data with code=RISK_CLASS_ID)."
                ),
                "applicableLegislationId": Schema.number(
                    "Numeric legislation id (see search_reference_data with code=APPLICABLE_LEGISLATION_ID)."
                ),
                "placedOnTheMarketId": Schema.number(
                    "Numeric market id (see search_reference_data with code=PLACED_ON_THE_MARKET_ID)."
                ),
                "mfSrn": Schema.string("Single Registration Number (SRN) of the manufacturer."),
                "specialDeviceTypeId": Schema.number("Numeric special device type id."),
                "medicalPurpose": Schema.string("Free-text medical purpose of the device."),
            ])
        ),
        Tool(
            name: "get_udi_device",
            description: "Look up a single UDI device record by its exact Primary Device Identifier.",
            inputSchema: Schema.object(
                ["primaryDi": Schema.string("The Primary Device Identifier (Primary DI) to look up.")],
                required: ["primaryDi"]
            )
        ),
        Tool(
            name: "search_reference_data",
            description: """
                Search EUDAMED reference/nomenclature data: lookup tables used to resolve \
                numeric ids to human-readable labels (e.g. risk classes, legislations, \
                statuses, countries). All filters are optional.
                """,
            inputSchema: Schema.object([
                "id": Schema.number("Numeric identifier of the reference entry."),
                "code": Schema.string(
                    "Reference data group code, e.g. RISK_CLASS_ID, APPLICABLE_LEGISLATION_ID, STATUS_ID, DEVICE_STATUS_TYPE_ID, PLACED_ON_THE_MARKET_ID."
                ),
                "language": Schema.string("Language code of the localized value, e.g. en, fr, de."),
            ])
        ),
        Tool(
            name: "get_reference_value",
            description: "Resolve a single reference data label by its numeric id, group code, and language.",
            inputSchema: Schema.object(
                [
                    "id": Schema.number("Numeric identifier of the reference entry."),
                    "code": Schema.string("Reference data group code, e.g. RISK_CLASS_ID."),
                    "language": Schema.string("Language code, e.g. en, fr, de. Defaults to \"en\"."),
                ],
                required: ["id", "code"]
            )
        ),
    ]

    // MARK: - Tool dispatch

    func call(_ params: CallTool.Parameters) async -> CallTool.Result {
        let arguments = params.arguments ?? [:]
        do {
            switch params.name {
            case "search_actors":
                let query = ActorQuery(
                    actorId: arguments.string("actorId"),
                    name: arguments.string("name"),
                    abbreviatedName: arguments.string("abbreviatedName"),
                    actorType: arguments.string("actorType"),
                    countryIso2Code: arguments.string("countryIso2Code")
                )
                let results = try await actors.search(query: query)
                return textResult(JSONText.encode(results))

            case "get_actor":
                guard let actorId = arguments.string("actorId") else {
                    return errorResult("Missing required argument: actorId")
                }
                let result = try await actors.actor(id: actorId)
                return textResult(JSONText.encode(result))

            case "search_udi_devices":
                let query = UdiDevicesQuery(
                    primaryDi: arguments.string("primaryDi"),
                    basicUdi: arguments.string("basicUdi"),
                    tradeName: arguments.string("tradeName"),
                    deviceName: arguments.string("deviceName"),
                    deviceModel: arguments.string("deviceModel"),
                    reference: arguments.string("reference"),
                    nomenclatureCode: arguments.string("nomenclatureCode"),
                    riskClassId: arguments.double("riskClassId"),
                    applicableLegislationId: arguments.double("applicableLegislationId"),
                    placedOnTheMarketId: arguments.double("placedOnTheMarketId"),
                    mfSrn: arguments.string("mfSrn"),
                    specialDeviceTypeId: arguments.double("specialDeviceTypeId"),
                    medicalPurpose: arguments.string("medicalPurpose")
                )
                let results = try await devices.search(query: query)
                return textResult(JSONText.encode(results))

            case "get_udi_device":
                guard let primaryDi = arguments.string("primaryDi") else {
                    return errorResult("Missing required argument: primaryDi")
                }
                let result = try await devices.device(primaryDi: primaryDi)
                return textResult(JSONText.encode(result))

            case "search_reference_data":
                let query = ReferenceQuery(
                    id: arguments.int("id"),
                    code: arguments.string("code"),
                    language: arguments.string("language")
                )
                let results = try await references.search(query: query)
                return textResult(JSONText.encode(results.map(ReferenceEntryDTO.init)))

            case "get_reference_value":
                guard let id = arguments.int("id"), let code = arguments.string("code") else {
                    return errorResult("Missing required argument: id and/or code")
                }
                let language = arguments.string("language") ?? "en"
                let value = await references.getReferenceValue(id: id, code: code, language: language)
                return textResult(JSONText.encode(value))

            default:
                return errorResult("Unknown tool: \(params.name)")
            }
        } catch {
            return errorResult("EUDAMED API request failed: \(error)")
        }
    }

    private func textResult(_ text: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: text, annotations: nil, _meta: nil)], isError: false)
    }

    private func errorResult(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(text: message, annotations: nil, _meta: nil)], isError: true)
    }
}

/// `ReferenceEntry` from EudamedClient doesn't conform to `Encodable`; mirror
/// its fields here so search results can be serialized to JSON.
private struct ReferenceEntryDTO: Encodable {
    let id: Int
    let code: String
    let language: String
    let value: String

    init(_ entry: ReferenceEntry) {
        id = entry.id
        code = entry.code
        language = entry.language
        value = entry.value
    }
}
