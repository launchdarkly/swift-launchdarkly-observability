import Foundation
import MachO

/// Builds the structured `ld-apple-1` stacktrace payload from the *current*
/// thread's call stack, so a handled error can be symbolicated by the backend
/// against the uploaded dSYM `.ldsm` maps — exactly like a crash, but without
/// terminating the process.
///
/// This mirrors `AppleCrashPayloadBuilder` in the SDK, except the frames come
/// from live return addresses (`Thread.callStackReturnAddresses` + `dladdr` +
/// each image's `LC_UUID`) instead of a KSCrash report.
enum LiveBacktrace {
    /// The `ld-apple-1` JSON for the calling thread. `skip` drops the top frames
    /// belonging to this helper so the trace starts at the caller of interest.
    static func applePayloadJSON(skip: Int = 1) -> String {
        let addresses = Thread.callStackReturnAddresses.map { $0.uintValue }
        let uuidsByBase = imageUUIDsByLoadAddress()

        var frames = [[String: Any]]()
        for address in addresses.dropFirst(skip) {
            var info = Dl_info()
            guard dladdr(UnsafeRawPointer(bitPattern: address), &info) != 0 else {
                continue
            }
            let base = UInt(bitPattern: info.dli_fbase)
            let relOffset = address >= base ? address - base : 0
            let path = info.dli_fname.map { String(cString: $0) }

            var frame: [String: Any] = [
                "image_uuid": uuidsByBase[base] ?? "",
                "rel_offset": relOffset,
                "in_app": isAppImage(path),
            ]
            if let path {
                frame["module"] = (path as NSString).lastPathComponent
            }
            if let symbol = info.dli_sname {
                frame["symbol"] = String(cString: symbol)
            }
            frames.append(frame)
        }

        let payload: [String: Any] = ["format": "ld-apple-1", "frames": frames]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"format":"ld-apple-1","frames":[]}"#
        }
        return json
    }

    private static func isAppImage(_ path: String?) -> Bool {
        guard let path else { return false }
        return path.contains(".app/") && !path.contains("/Frameworks/")
    }

    /// Maps each loaded image's base (mach header) address to its build UUID
    /// (upper-case hex, no dashes) by scanning dyld's image list for LC_UUID.
    private static func imageUUIDsByLoadAddress() -> [UInt: String] {
        var result = [UInt: String]()
        for index in 0..<_dyld_image_count() {
            guard let header = _dyld_get_image_header(index) else {
                continue
            }
            let base = UInt(bitPattern: UnsafeRawPointer(header))
            if let uuid = uuid(forHeader: header) {
                result[base] = uuid
            }
        }
        return result
    }

    private static func uuid(forHeader header: UnsafePointer<mach_header>) -> String? {
        // 64-bit images only (all modern iOS/tvOS).
        guard header.pointee.magic == MH_MAGIC_64 else {
            return nil
        }
        let header64 = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        var cursor = UnsafeRawPointer(header).advanced(by: MemoryLayout<mach_header_64>.size)
        for _ in 0..<header64.pointee.ncmds {
            let command = cursor.assumingMemoryBound(to: load_command.self)
            if command.pointee.cmd == UInt32(LC_UUID) {
                let uuidCommand = cursor.assumingMemoryBound(to: uuid_command.self)
                return format(uuid: uuidCommand.pointee.uuid)
            }
            cursor = cursor.advanced(by: Int(command.pointee.cmdsize))
        }
        return nil
    }

    private static func format(uuid: uuid_t) -> String {
        let bytes = [
            uuid.0, uuid.1, uuid.2, uuid.3, uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11, uuid.12, uuid.13, uuid.14, uuid.15,
        ]
        return bytes.map { String(format: "%02X", $0) }.joined()
    }
}
