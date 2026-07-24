import Foundation

/// Catalog of crash / error scenarios the TestApp can produce on demand to
/// exercise Apple symbolication end-to-end.
///
/// Each scenario is triggered in one of two modes (see `Mode`):
/// - `.crash` terminates the process; KSCrash captures it and the SDK delivers
///   the structured `ld-apple-1` payload on the next launch, which the backend
///   symbolicates against the uploaded dSYM `.dsymmap` maps.
/// - `.error` runs the same failure but catches it (Swift `try`/`catch`) and
///   reports it live via `LDObserve.recordError`. Only available for scenarios
///   that are catchable — see `supportsHandled`.
///
/// Note: several Swift runtime traps (`assertionFailure`) are compiled out in
/// optimized/Release builds. When validating symbolication (a Release build with
/// a dSYM), prefer the always-fatal scenarios.
enum CrashScenario: String, CaseIterable, Identifiable {
    // Dual-mode: catchable, so both Error and Crash are meaningful.
    case throwingError       = "Throwing error"
    case castFailure         = "Type cast failure"
    case decodingFailure     = "JSON decoding failure"

    // Crash-only Swift runtime traps.
    case fatalError          = "fatalError()"
    case forceUnwrapNil      = "Force-unwrap nil optional"
    case arrayOutOfBounds    = "Array index out of range"
    case preconditionFailure = "preconditionFailure()"
    case assertionFailure    = "assertionFailure() (debug only)"
    case integerOverflow     = "Integer overflow"

    // Crash-only signals / exceptions.
    case badMemoryAccess     = "Bad memory access (SIGSEGV)"
    case abortSignal         = "abort() (SIGABRT)"
    case illegalInstruction  = "raise(SIGILL)"
    case nsException         = "NSException (NSRange)"
    case stackOverflow       = "Stack overflow (recursion)"

    // Multithreading: crash off the main thread (or race across threads),
    // exercising crashed-thread selection in the structured payload.
    case backgroundThreadCrash = "Background thread: fatalError()"
    case backgroundBadAccess   = "Background thread: bad memory access"
    case detachedTaskCrash     = "Detached Task: fatalError()"
    case concurrentMutation    = "Data race (concurrent mutation)"
    case busyThreadsThenCrash  = "Many threads busy, then crash"

    var id: String { rawValue }

    /// How a scenario is triggered.
    enum Mode {
        /// Catch the failure and report it via `LDObserve.recordError` — the
        /// stacktrace is the on-device `Thread.callStackSymbols` text.
        case error
        /// Catch the failure and report it with a structured `ld-apple-1` payload
        /// built from the call stack captured at the throw site, so the backend
        /// symbolicates it from the dSYM `.dsymmap` maps (same path as a crash,
        /// without terminating).
        case errorStructured
        /// Let the failure terminate the process (fatal).
        case crash
    }

    /// Whether the scenario can be caught with Swift `try`/`catch` and reported as
    /// a handled error. Pure runtime traps and signals cannot be caught, so they
    /// are crash-only.
    var supportsHandled: Bool {
        switch self {
        case .throwingError, .castFailure, .decodingFailure:
            return true
        default:
            return false
        }
    }
}

/// Wraps a thrown error together with the structured `ld-apple-1` backtrace
/// captured *at the throw site*. `LiveBacktrace` must be sampled while the
/// failing frames are still on the stack; sampling it later from the `catch`
/// block would only capture the reporting path (the error has already unwound),
/// so the throw-site frames the backend should symbolicate would be lost.
struct StructuredError: Error {
    let underlying: Error
    let stackTraceJSON: String
}
