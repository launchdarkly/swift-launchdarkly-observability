// StartupMetricsInit.c
extern void SwiftStartupMetricsInitialize(void);

__attribute__((constructor))
static void StartupMetricsEarlyInit(void) {
    SwiftStartupMetricsInitialize();
}
