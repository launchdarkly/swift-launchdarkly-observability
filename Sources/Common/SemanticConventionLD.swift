public enum SemanticConvention {
    public static let highlightSessionId = "highlight.session_id"
}

public enum LDSemanticAttribute {
    public static let ATTR_SAMPLING_RATIO = "launchdarkly.sampling.ratio"
    public enum System {
        public static let systemCpuUtilization = "system.cpu.utilization"
        public static let cpuLogicalNumber = "cpu.logical_number"
        public static let cpuMode = "cpu.mode"
    }
}
