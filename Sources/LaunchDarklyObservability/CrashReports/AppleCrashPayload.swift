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
        /// The runtime crash message KSCrash captured from this image's
        /// `__DATA,__crash_info` section — e.g. Swift's
        /// "Fatal error: Index out of range". Set on the image that trapped
        /// (app or libswiftCore), not under `crash.error`. Different OS/Swift
        /// versions populate `message`, `message2`, or `signature`, so all three
        /// are decoded and tried in order (see `bestCrashInfo`).
        let crashInfoMessage: String?
        let crashInfoMessage2: String?
        let crashInfoSignature: String?

        enum CodingKeys: String, CodingKey {
            case imageAddr = "image_addr"
            case imageVmaddr = "image_vmaddr"
            case uuid
            case name
            case crashInfoMessage = "crash_info_message"
            case crashInfoMessage2 = "crash_info_message2"
            case crashInfoSignature = "crash_info_signature"
        }

        /// The most descriptive crash-info string this image carries, if any.
        var bestCrashInfo: String? {
            for candidate in [crashInfoMessage, crashInfoMessage2, crashInfoSignature] {
                if let candidate, !candidate.isEmpty {
                    return candidate
                }
            }
            return nil
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
        // Swift runtime traps (e.g. "Index out of range", force-unwrap of nil)
        // carry no NSException/error reason; the message lives in the trapping
        // image's __crash_info section instead. This may be unavailable when the
        // OS emits a __crash_info version the installed KSCrash can't parse (e.g.
        // iOS 26+ with KSCrash 2.5.1), in which case we fall back below.
        if let message = crashInfoMessage(from: report), !message.isEmpty { return message }
        // Last resort: synthesize the most descriptive signal/mach label instead
        // of a bare, opaque code like "0" (a numeric signal/mach code_name).
        return signalDescription(from: error)
    }

    /// A human-readable mach/signal label (e.g. "EXC_BREAKPOINT (SIGTRAP)") used
    /// when no runtime message is available. Never returns a purely numeric code.
    private static func signalDescription(from error: KSCrashReportModel.CrashError?) -> String? {
        guard let error else {
            return nil
        }
        let mach = error.mach?.exceptionName.flatMap { $0.isEmpty ? nil : $0 }
        let signalName = error.signal?.name.flatMap { $0.isEmpty ? nil : $0 }
        let codeName = error.signal?.codeName.flatMap { $0.isEmpty ? nil : $0 }

        if let mach {
            return signalName.map { "\(mach) (\($0))" } ?? mach
        }
        // A named code (e.g. "SEGV_MAPERR") is more specific than the signal;
        // a purely numeric code (e.g. "0") is opaque, so skip it.
        if let codeName, !isNumeric(codeName) {
            return codeName
        }
        if let signalName {
            return signalName
        }
        if let type = error.type, !type.isEmpty {
            return type
        }
        return nil
    }

    private static func isNumeric(_ s: String) -> Bool {
        !s.isEmpty && s.allSatisfy(\.isNumber)
    }

    /// The Swift/Obj-C runtime crash message captured from an image's
    /// `__DATA,__crash_info` section. KSCrash records it per binary image (not
    /// under `crash.error`), so prefer the crashed thread's frame images
    /// (innermost first) and fall back to any image that captured a message.
    static func crashInfoMessage(from report: KSCrashReportModel) -> String? {
        let images = report.binaryImages ?? []
        guard !images.isEmpty else {
            return nil
        }

        var byLoadAddress = [UInt64: KSCrashReportModel.BinaryImage]()
        for image in images {
            if let addr = image.imageAddr {
                byLoadAddress[addr] = image
            }
        }

        let threads = report.crash?.threads ?? []
        let thread = threads.first(where: { $0.crashed == true }) ?? threads.first
        for frame in thread?.backtrace?.contents ?? [] {
            if let addr = frame.objectAddr,
               let message = byLoadAddress[addr]?.bestCrashInfo {
                return message
            }
        }

        return images.compactMap(\.bestCrashInfo).first
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
