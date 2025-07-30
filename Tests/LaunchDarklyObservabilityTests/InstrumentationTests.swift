import Testing
import LaunchDarklyObservability

struct InstrumentationTests {
    @Test
    func canUpdateSession() async {
        // Given
        let sesion = DefaultSession(sessionInfo: SessionInfo(sessionId: "test_session"))
        let instrumentation = DefaultInstrumentation(session: sesion)
        let sessionId = "test_session"
        let newSession = DefaultSession(sessionInfo: SessionInfo(sessionId: sessionId))
        
        // When
        await instrumentation.updateSession(newSession)
        
        // Then
        let sessionInfo = await instrumentation.sessionInfo()
        #expect(await newSession.sessionInfo == sessionInfo)
        #expect(sessionInfo.sessionId == sessionId)
    }
}
