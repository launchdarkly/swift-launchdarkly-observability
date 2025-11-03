// StartupMetricsInit.c
extern void SwiftStartupMetricsInitialize(void);

__attribute__((constructor))
static void StartupMetricsEarlyInit(void) {
    SwiftStartupMetricsInitialize();
}

//@_cdecl("SwiftStartupMetricsInitialize")
//@_attribute__((constructor))
//// Expose a function Swift can call from C
//public func SwiftStartupMetricsInitialize() {
//    _ = AppStartTime.stats
//}
