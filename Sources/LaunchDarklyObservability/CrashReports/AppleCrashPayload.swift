import Foundation

/// `AppleCrashPayload` is the structured crash representation ("ld-apple-1") the
/// SDK writes into the OpenTelemetry `exception.stacktrace` attribute in place of
/// the legacy Apple crash text. The backend sniffs the `format` discriminator and,
/// for each frame, looks up the uploaded `.dsymmap` symbol map keyed by `image_uuid`
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
    /// Descriptors for the threads `frames` came from, present only when the
    /// report carried more than the crashed thread. Omitted otherwise, which
    /// keeps single-thread payloads byte-identical to those sent before threads
    /// were reported at all.
    let threads: [ThreadInfo]?

    init(frames: [Frame], threads: [ThreadInfo]? = nil) {
        self.format = AppleCrashPayload.formatIdentifier
        self.frames = frames
        self.threads = threads
    }

    /// One thread in the report. Apple gives no stable thread id in a crash
    /// report, so the identity is KSCrash's `index`, and the name and dispatch
    /// queue label are what actually tell a reader which thread this was.
    struct ThreadInfo: Encodable, Equatable {
        let index: Int
        let name: String?
        let queue: String?
        let crashed: Bool
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
        /// fallback label until the backend resolves the .dsymmap map.
        let symbol: String?
        /// Whether the frame belongs to the app's main executable image.
        let inApp: Bool
        /// Index of the thread this frame was captured on, matching a
        /// `ThreadInfo.index`. Nil in single-thread payloads.
        let thread: Int?

        init(imageUUID: String, relOffset: UInt64, module: String?, symbol: String?, inApp: Bool, thread: Int? = nil) {
            self.imageUUID = imageUUID
            self.relOffset = relOffset
            self.module = module
            self.symbol = symbol
            self.inApp = inApp
            self.thread = thread
        }

        enum CodingKeys: String, CodingKey {
            case imageUUID = "image_uuid"
            case relOffset = "rel_offset"
            case module
            case symbol
            case inApp = "in_app"
            case thread
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
        /// The stack where an NSException / C++ exception was thrown. KSCrash
        /// records this separately from `threads` because the crashed thread's
        /// backtrace for an exception is the abort/handler stack, not the
        /// throw site. When present it is the authoritative stack to symbolicate.
        let lastExceptionBacktrace: Backtrace?

        enum CodingKeys: String, CodingKey {
            case threads, error
            case lastExceptionBacktrace = "last_exception_backtrace"
        }    
    }

    struct Thread: Decodable {
        let index: Int?
        let crashed: Bool?
        let backtrace: Backtrace?
        /// pthread name, when the thread was given one.
        let name: String?
        /// Label of the dispatch queue running on the thread, e.g.
        /// "com.apple.main-thread". Usually more recognizable than the name.
        let dispatchQueue: String?
        /// Set on the thread that was executing the crash handler. Used as a
        /// fallback when no thread is flagged `crashed` (user-reported reports).
        let currentThread: Bool?

        enum CodingKeys: String, CodingKey {
            case index, crashed, backtrace, name
            case dispatchQueue = "dispatch_queue"
            case currentThread = "current_thread"
        }
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
    /// report, ready to attach to a fatal log record. `stackTraceJSON` is nil when
    /// the report carried no usable backtrace — the caller must still emit the
    /// fatal log so the crash isn't dropped, just without the structured frames.
    struct StructuredCrash {
        let incidentIdentifier: String
        let exceptionType: String
        let exceptionMessage: String?
        let stackTraceJSON: String?
    }

    /// Decodes a raw KSCrash report (JSON-encoded dictionary) and produces the
    /// structured crash attributes. Always returns a `StructuredCrash` for a
    /// decodable report so the caller can always emit fatal telemetry; the
    /// structured stacktrace is nil when there is no usable backtrace.
    static func makeStructuredCrash(fromReportData data: Data) throws -> StructuredCrash {
        let report = try JSONDecoder().decode(KSCrashReportModel.self, from: data)
        return StructuredCrash(
            incidentIdentifier: incidentIdentifier(from: report),
            exceptionType: exceptionType(from: report),
            exceptionMessage: exceptionMessage(from: report),
            stackTraceJSON: stackTraceJSON(from: report)
        )
    }

    /// Encodes the crashed thread's backtrace as the "ld-apple-1" wire JSON, or
    /// nil when the report has no usable backtrace (or encoding fails). A missing
    /// stacktrace must not prevent the fatal log from being sent.
    static func stackTraceJSON(from report: KSCrashReportModel) -> String? {
        guard let payload = payload(from: report) else {
            return nil
        }
        guard let encoded = try? JSONEncoder().encode(payload) else {
            return nil
        }
        return String(data: encoded, encoding: .utf8)
    }

    /// The authoritative crash backtrace to symbolicate, deepest-first.
    ///
    /// For NSException / C++ exception crashes KSCrash records the throw-site
    /// stack in `last_exception_backtrace`; the crashed thread's own backtrace is
    /// only the abort/handler stack, so it is not the stack we want. Prefer the
    /// exception backtrace when present, otherwise the crashed thread's own.
    ///
    /// Thread selection goes through `crashedThread(in:)` so the frames returned
    /// here and the thread they get attributed to can never disagree.
    static func crashBacktrace(from report: KSCrashReportModel) -> [KSCrashReportModel.Frame] {
        if let contents = report.crash?.lastExceptionBacktrace?.contents, !contents.isEmpty {
            return contents
        }
        return crashedThread(in: report.crash?.threads ?? [])?.backtrace?.contents ?? []
    }

    /// Upper bound on threads reported besides the crashed one. A busy app can
    /// have dozens of idle worker threads whose stacks are all the same handful
    /// of scheduler frames; past a few dozen they cost payload and symbolication
    /// without telling a reader anything.
    static let maxBackgroundThreads = 31

    /// Upper bound on frames kept per background thread. The crashed thread is
    /// never truncated -- it is the stack being investigated -- but a background
    /// thread's story is told by its top frames.
    static let maxFramesPerBackgroundThread = 64

    /// Converts the report's backtraces into structured frames. Returns nil when
    /// there is no crash backtrace to symbolicate.
    ///
    /// The crashed thread comes first and in full, so a consumer that ignores
    /// thread grouping still reads the crash stack exactly as before. Background
    /// threads follow in index order, each tagged with its thread index, and the
    /// payload gains a `threads` descriptor list. A report with nothing but the
    /// crashed thread produces the same single-thread payload it always did.
    static func payload(from report: KSCrashReportModel) -> AppleCrashPayload? {
        let crashContents = crashBacktrace(from: report)
        guard !crashContents.isEmpty else {
            return nil
        }

        var imagesByLoadAddress = [UInt64: KSCrashReportModel.BinaryImage]()
        for image in report.binaryImages ?? [] {
            if let addr = image.imageAddr {
                imagesByLoadAddress[addr] = image
            }
        }
        // KSCrash reports the app's name in both `process_name` and
        // `CFBundleExecutable`, and these can differ (e.g. when the bundle
        // display name and the executable filename don't match). A frame belongs
        // to the main binary if its module matches either, so match against the
        // full set instead of a single value.
        let appExecutables = Set(
            [report.system?.processName, report.system?.executable].compactMap(moduleName)
        )
        let convert: ([KSCrashReportModel.Frame], Int?) -> [AppleCrashPayload.Frame] = { contents, threadIndex in
            structuredFrames(
                from: contents,
                imagesByLoadAddress: imagesByLoadAddress,
                appExecutables: appExecutables,
                threadIndex: threadIndex
            )
        }

        let allThreads = report.crash?.threads ?? []
        let crashedThread = crashedThread(in: allThreads)
        let background = backgroundThreads(in: allThreads, crashed: crashedThread)

        // Only tag frames with a thread once there is more than one thread to
        // tell apart; a lone index on every frame would be noise.
        guard let crashedIndex = crashedThread?.index, !background.isEmpty else {
            let frames = convert(crashContents, nil)
            return frames.isEmpty ? nil : AppleCrashPayload(frames: frames)
        }

        var frames = convert(crashContents, crashedIndex)
        guard !frames.isEmpty else {
            return nil
        }
        var descriptors = [describe(crashedThread, crashed: true)].compactMap { $0 }

        for thread in background {
            let contents = Array((thread.backtrace?.contents ?? []).prefix(maxFramesPerBackgroundThread))
            let threadFrames = convert(contents, thread.index)
            guard !threadFrames.isEmpty, let descriptor = describe(thread, crashed: false) else {
                continue
            }
            frames.append(contentsOf: threadFrames)
            descriptors.append(descriptor)
        }

        return AppleCrashPayload(frames: frames, threads: descriptors.count > 1 ? descriptors : nil)
    }

    /// The thread the crash is attributed to: the one KSCrash flagged `crashed`,
    /// else the one running the crash handler (user-reported reports flag no
    /// crashed thread), else the first.
    static func crashedThread(in threads: [KSCrashReportModel.Thread]) -> KSCrashReportModel.Thread? {
        threads.first(where: { $0.crashed == true })
            ?? threads.first(where: { $0.currentThread == true })
            ?? threads.first
    }

    /// Every other thread with a backtrace, in index order, capped.
    static func backgroundThreads(
        in threads: [KSCrashReportModel.Thread],
        crashed: KSCrashReportModel.Thread?
    ) -> [KSCrashReportModel.Thread] {
        threads
            .filter { $0.index != nil && $0.index != crashed?.index }
            .filter { !($0.backtrace?.contents ?? []).isEmpty }
            .sorted { ($0.index ?? 0) < ($1.index ?? 0) }
            .prefix(maxBackgroundThreads)
            .map { $0 }
    }

    static func describe(
        _ thread: KSCrashReportModel.Thread?,
        crashed: Bool
    ) -> AppleCrashPayload.ThreadInfo? {
        guard let thread, let index = thread.index else {
            return nil
        }
        return AppleCrashPayload.ThreadInfo(
            index: index,
            name: thread.name.flatMap { $0.isEmpty ? nil : $0 },
            queue: thread.dispatchQueue.flatMap { $0.isEmpty ? nil : $0 },
            crashed: crashed
        )
    }

    /// Converts one thread's raw KSCrash frames into wire frames, resolving each
    /// to its image so the backend can look up a symbol map.
    static func structuredFrames(
        from contents: [KSCrashReportModel.Frame],
        imagesByLoadAddress: [UInt64: KSCrashReportModel.BinaryImage],
        appExecutables: Set<String>,
        threadIndex: Int?
    ) -> [AppleCrashPayload.Frame] {
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
            let inApp = module.map(appExecutables.contains) ?? false
            let symbol = frame.symbolName.flatMap { $0.isEmpty ? nil : $0 }
            frames.append(
                AppleCrashPayload.Frame(
                    imageUUID: normalizeUUID(image?.uuid),
                    relOffset: relOffset,
                    module: module,
                    symbol: symbol,
                    inApp: inApp,
                    thread: threadIndex
                )
            )
        }
        return frames
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
    /// under `crash.error`), so prefer the authoritative backtrace's frame images
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

        for frame in crashBacktrace(from: report) {
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
