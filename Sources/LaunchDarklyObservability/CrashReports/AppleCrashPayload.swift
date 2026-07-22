import Foundation

/// `AppleCrashPayload` is the structured crash representation ("ld-apple-1") the
/// SDK writes into the OpenTelemetry `exception.stacktrace` attribute in place of
/// the legacy Apple crash text. The backend sniffs the `format` discriminator and,
/// for each frame, looks up the uploaded `.ldsm` symbol map keyed by `image_uuid`
/// and resolves the source location from `rel_offset` (the image-relative
/// instruction offset). `module`/`symbol`/`in_app` drive display and the
/// un-symbolicated fallback.
///
/// Frames are ordered deepest-first (crash frame first), matching KSCrash's
/// backtrace order and the backend's stored-frame convention.
struct AppleCrashPayload: Encodable, Equatable {
    /// The frozen format identifier the backend matches on.
    static let formatIdentifier = "ld-apple-1"

    let format: String
    let frames: [Frame]

    init(frames: [Frame]) {
        self.format = AppleCrashPayload.formatIdentifier
        self.frames = frames
    }

    struct Frame: Encodable, Equatable {
        /// Build UUID of the image the frame belongs to, canonicalized to upper
        /// case hex with dashes stripped (matches the ldcli upload key).
        let imageUUID: String
        /// instruction_addr - image_load_addr. Zero when the load address is
        /// unknown (system frames with no reported image).
        let relOffset: UInt64
        /// Image basename (e.g. "MyApp", "libswiftCore.dylib").
        let module: String?
        /// On-device symbol name, when the OS symbolicated the frame. Serves as a
        /// fallback label until the backend resolves the .ldsm map.
        let symbol: String?
        /// Whether the frame belongs to the app's main executable image.
        let inApp: Bool

        enum CodingKeys: String, CodingKey {
            case imageUUID = "image_uuid"
            case relOffset = "rel_offset"
            case module
            case symbol
            case inApp = "in_app"
        }
    }
}

/// `KSCrashReportModel` decodes only the fields of a KSCrash report needed to
/// build an `AppleCrashPayload`. Every field is optional so a partial or
/// unexpected report degrades gracefully instead of failing to decode. Keys
/// mirror KSCrash's report field constants (see KSCrashReportFields.h).
struct KSCrashReportModel: Decodable {
    let report: ReportInfo?
    let system: SystemInfo?
    let crash: CrashInfo?
    let binaryImages: [BinaryImage]?

    enum CodingKeys: String, CodingKey {
        case report, system, crash
        case binaryImages = "binary_images"
    }

    struct ReportInfo: Decodable {
        let id: String?
    }

    struct SystemInfo: Decodable {
        let processName: String?
        let executable: String?

        enum CodingKeys: String, CodingKey {
            case processName = "process_name"
            case executable = "CFBundleExecutable"
        }
    }

    struct CrashInfo: Decodable {
        let threads: [Thread]?
        let error: CrashError?
    }

    struct Thread: Decodable {
        let index: Int?
        let crashed: Bool?
        let backtrace: Backtrace?
    }

    struct Backtrace: Decodable {
        let contents: [Frame]?
    }

    struct Frame: Decodable {
        let instructionAddr: UInt64?
        let objectAddr: UInt64?
        let objectName: String?
        let symbolAddr: UInt64?
        let symbolName: String?

        enum CodingKeys: String, CodingKey {
            case instructionAddr = "instruction_addr"
            case objectAddr = "object_addr"
            case objectName = "object_name"
            case symbolAddr = "symbol_addr"
            case symbolName = "symbol_name"
        }
    }

    struct BinaryImage: Decodable {
        let imageAddr: UInt64?
        let imageVmaddr: UInt64?
        let uuid: String?
        let name: String?

        enum CodingKeys: String, CodingKey {
            case imageAddr = "image_addr"
            case imageVmaddr = "image_vmaddr"
            case uuid
            case name
        }
    }

    struct CrashError: Decodable {
        let type: String?
        let reason: String?
        let signal: Signal?
        let mach: Mach?
        let nsexception: NSExceptionInfo?
        let cppException: CPPException?

        enum CodingKeys: String, CodingKey {
            case type, reason, signal, mach, nsexception
            case cppException = "cpp_exception"
        }
    }

    struct Signal: Decodable {
        let name: String?
        let codeName: String?

        enum CodingKeys: String, CodingKey {
            case name
            case codeName = "code_name"
        }
    }

    struct Mach: Decodable {
        let exceptionName: String?

        enum CodingKeys: String, CodingKey {
            case exceptionName = "exception_name"
        }
    }

    struct NSExceptionInfo: Decodable {
        let name: String?
        let reason: String?
    }

    struct CPPException: Decodable {
        let name: String?
    }
}

/// Builds the `ld-apple-1` payload (and the associated exception attributes) from
/// a raw KSCrash report. Kept free of any KSCrash imports so it can be unit
/// tested against JSON fixtures.
enum AppleCrashPayloadBuilder {
    /// The exception attributes and structured stacktrace derived from one crash
    /// report, ready to attach to a fatal log record.
    struct StructuredCrash {
        let incidentIdentifier: String
        let exceptionType: String
        let exceptionMessage: String?
        let stackTraceJSON: String
    }

    /// Decodes a raw KSCrash report (JSON-encoded dictionary) and produces the
    /// structured crash attributes. Returns nil when the report has no usable
    /// backtrace so the caller can skip it.
    static func makeStructuredCrash(fromReportData data: Data) throws -> StructuredCrash? {
        let report = try JSONDecoder().decode(KSCrashReportModel.self, from: data)
        guard let payload = payload(from: report) else {
            return nil
        }
        let encoded = try JSONEncoder().encode(payload)
        guard let json = String(data: encoded, encoding: .utf8) else {
            return nil
        }
        return StructuredCrash(
            incidentIdentifier: incidentIdentifier(from: report),
            exceptionType: exceptionType(from: report),
            exceptionMessage: exceptionMessage(from: report),
            stackTraceJSON: json
        )
    }

    /// Converts the crashed thread's backtrace into structured frames. Returns
    /// nil when there is no thread with a backtrace to symbolicate.
    static func payload(from report: KSCrashReportModel) -> AppleCrashPayload? {
        guard let threads = report.crash?.threads, !threads.isEmpty else {
            return nil
        }
        // Prefer the crashed thread; fall back to the first thread for
        // user-reported reports that don't flag one.
        let thread = threads.first(where: { $0.crashed == true }) ?? threads.first
        guard let contents = thread?.backtrace?.contents, !contents.isEmpty else {
            return nil
        }

        var imagesByLoadAddress = [UInt64: KSCrashReportModel.BinaryImage]()
        for image in report.binaryImages ?? [] {
            if let addr = image.imageAddr {
                imagesByLoadAddress[addr] = image
            }
        }
        let appExecutable = report.system?.processName ?? report.system?.executable

        var frames = [AppleCrashPayload.Frame]()
        frames.reserveCapacity(contents.count)
        for frame in contents {
            guard let pc = frame.instructionAddr else {
                continue
            }
            let loadAddress = frame.objectAddr
            let image = loadAddress.flatMap { imagesByLoadAddress[$0] }
            let relOffset: UInt64
            if let loadAddress, pc >= loadAddress {
                relOffset = pc - loadAddress
            } else {
                relOffset = 0
            }
            let module = moduleName(image?.name ?? frame.objectName)
            let inApp = appExecutable != nil && module == appExecutable
            let symbol = frame.symbolName.flatMap { $0.isEmpty ? nil : $0 }
            frames.append(
                AppleCrashPayload.Frame(
                    imageUUID: normalizeUUID(image?.uuid),
                    relOffset: relOffset,
                    module: module,
                    symbol: symbol,
                    inApp: inApp
                )
            )
        }
        guard !frames.isEmpty else {
            return nil
        }
        return AppleCrashPayload(frames: frames)
    }

    /// Derives a human-readable exception type, preferring the most specific
    /// name the report carries.
    static func exceptionType(from report: KSCrashReportModel) -> String {
        guard let error = report.crash?.error else {
            return "Crash"
        }
        if let name = error.nsexception?.name, !name.isEmpty { return name }
        if let name = error.cppException?.name, !name.isEmpty { return name }
        if let name = error.mach?.exceptionName, !name.isEmpty { return name }
        if let name = error.signal?.name, !name.isEmpty { return name }
        if let type = error.type, !type.isEmpty { return type }
        return "Crash"
    }

    static func exceptionMessage(from report: KSCrashReportModel) -> String? {
        let error = report.crash?.error
        if let reason = error?.nsexception?.reason, !reason.isEmpty { return reason }
        if let reason = error?.reason, !reason.isEmpty { return reason }
        if let code = error?.signal?.codeName, !code.isEmpty { return code }
        return nil
    }

    static func incidentIdentifier(from report: KSCrashReportModel) -> String {
        report.report?.id ?? ""
    }

    static func moduleName(_ path: String?) -> String? {
        guard let path, !path.isEmpty else {
            return nil
        }
        return (path as NSString).lastPathComponent
    }

    /// Canonicalizes an image UUID to upper-case hex without dashes so it matches
    /// the storage key ldcli derives from the Mach-O LC_UUID.
    static func normalizeUUID(_ uuid: String?) -> String {
        guard let uuid else {
            return ""
        }
        return uuid.replacingOccurrences(of: "-", with: "").uppercased()
    }
}
