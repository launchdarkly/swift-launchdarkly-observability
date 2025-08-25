import Foundation

// MARK: - System
public struct System: Codable, Hashable, Sendable {
    public let systemName: String
    public let systemVersion: String
    public let machine: String
    public let model: String
    public let kernelVersion: String
    public let osVersion: String
    public let jailbroken: Bool
    public let bootTime: String?
    public let appStartTime: Date
    public let cfBundleExecutablePath: String
    public let cfBundleExecutable: String
    public let cfBundleIdentifier: String
    public let cfBundleName: String
    public let cfBundleVersion: String
    public let cfBundleShortVersionString: String
    public let appUUID: String
    public let cpuArch: String
    public let cpuType: Int
    public let cpuSubtype: Int
    public let binaryCPUType: Int
    public let binaryCPUSubtype: Int
    public let timeZone: String
    public let processName: String
    public let processID: Int
    public let parentProcessID: Int
    public let deviceAppHash: String
    public let buildType: String
    public let storage: Int
    public let memory: Memory
    public let applicationStats: ApplicationStats
    public let appMemory: AppMemory

    public enum CodingKeys: String, CodingKey {
        case systemName = "system_name"
        case systemVersion = "system_version"
        case machine = "machine"
        case model = "model"
        case kernelVersion = "kernel_version"
        case osVersion = "os_version"
        case jailbroken = "jailbroken"
        case bootTime = "boot_time"
        case appStartTime = "app_start_time"
        case cfBundleExecutablePath = "CFBundleExecutablePath"
        case cfBundleExecutable = "CFBundleExecutable"
        case cfBundleIdentifier = "CFBundleIdentifier"
        case cfBundleName = "CFBundleName"
        case cfBundleVersion = "CFBundleVersion"
        case cfBundleShortVersionString = "CFBundleShortVersionString"
        case appUUID = "app_uuid"
        case cpuArch = "cpu_arch"
        case cpuType = "cpu_type"
        case cpuSubtype = "cpu_subtype"
        case binaryCPUType = "binary_cpu_type"
        case binaryCPUSubtype = "binary_cpu_subtype"
        case timeZone = "time_zone"
        case processName = "process_name"
        case processID = "process_id"
        case parentProcessID = "parent_process_id"
        case deviceAppHash = "device_app_hash"
        case buildType = "build_type"
        case storage = "storage"
        case memory = "memory"
        case applicationStats = "application_stats"
        case appMemory = "app_memory"
    }

    public init(systemName: String, systemVersion: String, machine: String, model: String, kernelVersion: String, osVersion: String, jailbroken: Bool, bootTime: String?, appStartTime: Date, cfBundleExecutablePath: String, cfBundleExecutable: String, cfBundleIdentifier: String, cfBundleName: String, cfBundleVersion: String, cfBundleShortVersionString: String, appUUID: String, cpuArch: String, cpuType: Int, cpuSubtype: Int, binaryCPUType: Int, binaryCPUSubtype: Int, timeZone: String, processName: String, processID: Int, parentProcessID: Int, deviceAppHash: String, buildType: String, storage: Int, memory: Memory, applicationStats: ApplicationStats, appMemory: AppMemory) {
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.machine = machine
        self.model = model
        self.kernelVersion = kernelVersion
        self.osVersion = osVersion
        self.jailbroken = jailbroken
        self.bootTime = bootTime
        self.appStartTime = appStartTime
        self.cfBundleExecutablePath = cfBundleExecutablePath
        self.cfBundleExecutable = cfBundleExecutable
        self.cfBundleIdentifier = cfBundleIdentifier
        self.cfBundleName = cfBundleName
        self.cfBundleVersion = cfBundleVersion
        self.cfBundleShortVersionString = cfBundleShortVersionString
        self.appUUID = appUUID
        self.cpuArch = cpuArch
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
        self.binaryCPUType = binaryCPUType
        self.binaryCPUSubtype = binaryCPUSubtype
        self.timeZone = timeZone
        self.processName = processName
        self.processID = processID
        self.parentProcessID = parentProcessID
        self.deviceAppHash = deviceAppHash
        self.buildType = buildType
        self.storage = storage
        self.memory = memory
        self.applicationStats = applicationStats
        self.appMemory = appMemory
    }
}
