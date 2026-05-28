import Testing
@testable import LaunchDarklySessionReplay

struct SessionReplayOptionsTests {
    @Test("frameRate defaults to one frame per second")
    func frameRateDefaultsToOne() {
        #expect(SessionReplayOptions().frameRate == 1.0)
    }

    @Test("renderStrategy defaults to drawHierarchy")
    func renderStrategyDefaultsToDrawHierarchy() {
        #expect(SessionReplayOptions().renderStrategy == .drawHierarchy)
    }

    @Test("frameRate and renderStrategy can be configured")
    func frameRateAndRenderStrategyAreConfigurable() {
        let options = SessionReplayOptions(frameRate: 2.0, renderStrategy: .drawLayers)
        #expect(options.frameRate == 2.0)
        #expect(options.renderStrategy == .drawLayers)
    }
}
