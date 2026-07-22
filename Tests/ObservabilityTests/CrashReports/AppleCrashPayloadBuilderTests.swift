import Testing
import Foundation
@testable import LaunchDarklyObservability

@Suite
struct AppleCrashPayloadBuilderTests {

    // A trimmed but structurally faithful KSCrash report: two threads (the
    // crashed one is *not* first, to prove crashed-thread selection), a mix of
    // app / system images, and a frame whose image is missing from
    // `binary_images`. Addresses are chosen so the image-relative offsets are
    // round numbers: pc - object_addr.
    static let fixture = """
    {
      "report": { "id": "ABC-123", "timestamp": "2026-07-21T00:00:00Z" },
      "system": { "process_name": "TestApp", "CFBundleExecutable": "TestApp" },
      "crash": {
        "error": {
          "type": "signal",
          "signal": { "name": "SIGSEGV", "code_name": "SEGV_MAPERR" }
        },
        "threads": [
          {
            "index": 0,
            "crashed": false,
            "backtrace": { "contents": [
              { "instruction_addr": 999, "object_addr": 999, "object_name": "/usr/lib/dyld" }
            ] }
          },
          {
            "index": 1,
            "crashed": true,
            "backtrace": { "contents": [
              { "instruction_addr": 4294971392, "object_addr": 4294967296, "object_name": "/private/var/containers/Bundle/Application/AAA/TestApp.app/TestApp", "symbol_name": "$s7TestApp5crashyyF" },
              { "instruction_addr": 6442455296, "object_addr": 6442450944, "object_name": "/usr/lib/swift/libswiftCore.dylib" },
              { "instruction_addr": 8589934672, "object_addr": 8589934592, "object_name": "/usr/lib/system/libsystem_kernel.dylib" }
            ] }
          }
        ]
      },
      "binary_images": [
        { "image_addr": 4294967296, "image_vmaddr": 4294967296, "image_size": 65536, "uuid": "A5121984-B70C-3CA0-BCC2-2FB671D75A20", "name": "/private/var/containers/Bundle/Application/AAA/TestApp.app/TestApp" },
        { "image_addr": 6442450944, "image_vmaddr": 0, "image_size": 1048576, "uuid": "11111111-2222-3333-4444-555555555555", "name": "/usr/lib/swift/libswiftCore.dylib" }
      ]
    }
    """

    private func decodeFixture() throws -> KSCrashReportModel {
        try JSONDecoder().decode(KSCrashReportModel.self, from: Data(Self.fixture.utf8))
    }

    @Test("Builds deepest-first structured frames from the crashed thread")
    func buildsStructuredFrames() throws {
        let report = try decodeFixture()
        let payload = try #require(AppleCrashPayloadBuilder.payload(from: report))

        #expect(payload.format == "ld-apple-1")
        #expect(payload.frames.count == 3)

        // App frame: full metadata, dashes stripped + upper-cased UUID, in_app.
        let app = payload.frames[0]
        #expect(app.imageUUID == "A5121984B70C3CA0BCC22FB671D75A20")
        #expect(app.relOffset == 4096)
        #expect(app.module == "TestApp")
        #expect(app.symbol == "$s7TestApp5crashyyF")
        #expect(app.inApp == true)

        // System frame from a known image: uuid resolved, no symbol, not in_app.
        let core = payload.frames[1]
        #expect(core.imageUUID == "11111111222233334444555555555555")
        #expect(core.relOffset == 4352)
        #expect(core.module == "libswiftCore.dylib")
        #expect(core.symbol == nil)
        #expect(core.inApp == false)

        // Frame whose image is absent from binary_images: empty uuid, offset
        // still computed from the reported load address.
        let unknown = payload.frames[2]
        #expect(unknown.imageUUID == "")
        #expect(unknown.relOffset == 80)
        #expect(unknown.module == "libsystem_kernel.dylib")
        #expect(unknown.inApp == false)
    }

    @Test("Derives exception attributes and a valid wire JSON payload")
    func makesStructuredCrash() throws {
        let crash = try AppleCrashPayloadBuilder.makeStructuredCrash(fromReportData: Data(Self.fixture.utf8))

        #expect(crash.incidentIdentifier == "ABC-123")
        #expect(crash.exceptionType == "SIGSEGV")
        #expect(crash.exceptionMessage == "SEGV_MAPERR")
        let stackTraceJSON = try #require(crash.stackTraceJSON)
        #expect(stackTraceJSON.contains("ld-apple-1"))
        #expect(stackTraceJSON.contains("image_uuid"))
        #expect(stackTraceJSON.contains("rel_offset"))

        // The stacktrace must be valid JSON with the frozen shape.
        let object = try JSONSerialization.jsonObject(with: Data(stackTraceJSON.utf8)) as? [String: Any]
        #expect(object?["format"] as? String == "ld-apple-1")
        #expect((object?["frames"] as? [[String: Any]])?.count == 3)
    }

    @Test("Still produces exception attributes (no stacktrace) when there is no backtrace")
    func makesStructuredCrashWithoutBacktrace() throws {
        // No usable backtrace: the crash must not be dropped — we still surface
        // the exception type/message, just without the structured stacktrace.
        let json = """
        {
          "report": { "id": "NO-BT-1" },
          "crash": {
            "error": {
              "type": "signal",
              "signal": { "name": "SIGABRT", "code_name": "ABRT_TERMINATE" }
            },
            "threads": []
          }
        }
        """
        let crash = try AppleCrashPayloadBuilder.makeStructuredCrash(fromReportData: Data(json.utf8))

        #expect(crash.incidentIdentifier == "NO-BT-1")
        #expect(crash.exceptionType == "SIGABRT")
        #expect(crash.exceptionMessage == "ABRT_TERMINATE")
        #expect(crash.stackTraceJSON == nil)
    }

    @Test("Prefers NSException name/reason for the exception type and message")
    func nsExceptionAttributes() throws {
        let json = """
        {
          "crash": {
            "error": {
              "type": "nsexception",
              "nsexception": { "name": "NSRangeException", "reason": "index 5 beyond bounds" }
            },
            "threads": [
              { "crashed": true, "backtrace": { "contents": [
                { "instruction_addr": 4294971392, "object_addr": 4294967296, "object_name": "TestApp" }
              ] } }
            ]
          },
          "binary_images": [
            { "image_addr": 4294967296, "uuid": "AAAA-BBBB", "name": "TestApp" }
          ]
        }
        """
        let report = try JSONDecoder().decode(KSCrashReportModel.self, from: Data(json.utf8))
        #expect(AppleCrashPayloadBuilder.exceptionType(from: report) == "NSRangeException")
        #expect(AppleCrashPayloadBuilder.exceptionMessage(from: report) == "index 5 beyond bounds")
    }

    @Test("Surfaces the Swift runtime crash_info_message for a trap, not the signal code")
    func swiftTrapCrashInfoMessage() throws {
        // A Swift "Index out of range" trap: EXC_BREAKPOINT/SIGTRAP with no
        // NSException/error reason and an unhelpful code_name; the real message
        // lives in the trapping image's crash_info_message.
        let json = """
        {
          "crash": {
            "error": {
              "type": "signal",
              "signal": { "name": "SIGTRAP", "code_name": "0" }
            },
            "threads": [
              { "crashed": true, "backtrace": { "contents": [
                { "instruction_addr": 4294971392, "object_addr": 4294967296, "object_name": "TestApp" }
              ] } }
            ]
          },
          "binary_images": [
            { "image_addr": 4294967296, "uuid": "AAAA-BBBB", "name": "TestApp", "crash_info_message": "Fatal error: Index out of range" }
          ]
        }
        """
        let report = try JSONDecoder().decode(KSCrashReportModel.self, from: Data(json.utf8))
        #expect(AppleCrashPayloadBuilder.exceptionType(from: report) == "SIGTRAP")
        #expect(AppleCrashPayloadBuilder.exceptionMessage(from: report) == "Fatal error: Index out of range")
    }

    @Test("Falls back to a signal/mach label, never a bare numeric code")
    func numericSignalCodeFallback() throws {
        // iOS 26+ with KSCrash 2.5.1: no crash_info_message captured, and the
        // signal code_name is the opaque "0". We must not surface "0".
        let json = """
        {
          "crash": {
            "error": {
              "type": "mach",
              "signal": { "name": "SIGTRAP", "code_name": "0" },
              "mach": { "exception_name": "EXC_BREAKPOINT" }
            },
            "threads": [
              { "crashed": true, "backtrace": { "contents": [
                { "instruction_addr": 4294971392, "object_addr": 4294967296, "object_name": "TestApp" }
              ] } }
            ]
          },
          "binary_images": [
            { "image_addr": 4294967296, "uuid": "AAAA-BBBB", "name": "TestApp" }
          ]
        }
        """
        let report = try JSONDecoder().decode(KSCrashReportModel.self, from: Data(json.utf8))
        #expect(AppleCrashPayloadBuilder.exceptionMessage(from: report) == "EXC_BREAKPOINT (SIGTRAP)")
    }

    @Test("Returns nil when there is no thread with a backtrace")
    func noBacktraceReturnsNil() throws {
        let json = """
        { "crash": { "error": { "type": "signal" }, "threads": [] } }
        """
        let report = try JSONDecoder().decode(KSCrashReportModel.self, from: Data(json.utf8))
        #expect(AppleCrashPayloadBuilder.payload(from: report) == nil)
    }

    @Test("normalizeUUID strips dashes and upper-cases; moduleName takes basename")
    func helpers() {
        #expect(AppleCrashPayloadBuilder.normalizeUUID("a512-1984") == "A5121984")
        #expect(AppleCrashPayloadBuilder.normalizeUUID(nil) == "")
        #expect(AppleCrashPayloadBuilder.moduleName("/usr/lib/libswiftCore.dylib") == "libswiftCore.dylib")
        #expect(AppleCrashPayloadBuilder.moduleName(nil) == nil)
    }
}
