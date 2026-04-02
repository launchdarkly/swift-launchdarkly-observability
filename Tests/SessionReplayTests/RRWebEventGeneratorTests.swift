import Testing
@testable import LaunchDarklySessionReplay
@testable import LaunchDarklyObservability
import OSLog
import CoreGraphics
import Foundation

struct RRWebEventGeneratorTests {
    
    private func makeExportFrame(dataSize: Int,
                                 width: Int,
                                 height: Int,
                                 timestamp: TimeInterval,
                                 keyFrameId: Int = 0,
                                 isKeyframe: Bool = true) -> ExportFrame {
        let data = Data(count: dataSize)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let addImage = ExportFrame.AddImage(data: data, rect: rect, imageSignature: nil)
        return ExportFrame(
            keyFrameId: keyFrameId,
            addImages: [addImage],
            removeImages: nil,
            originalSize: CGSize(width: width, height: height),
            scale: 1.0,
            format: .png,
            timestamp: timestamp,
            orientation: 0,
            isKeyframe: isKeyframe,
            imageSignature: nil
        )
    }
    
    @Test("Appends draw image event when same size and below limit")
    func appendsDrawImageEventWhenSameSizeAndBelowLimit() async {
        // Arrange
        let generator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Test",
            method: .overlayTiles()
        )
        
        // First image triggers full snapshot (sets imageId and lastExportImage)
        let firstImage = makeExportFrame(dataSize: 128, width: 320, height: 480, timestamp: 1.0)
        // Second image has same dimensions but different data -> should append drawImageEvent branch
        let secondImage = makeExportFrame(dataSize: 256, width: 320, height: 480, timestamp: 2.0)
        
        let items: [EventQueueItem] = [
            EventQueueItem(payload: ImageItemPayload(exportFrame: firstImage)),
            EventQueueItem(payload: ImageItemPayload(exportFrame: secondImage))
        ]
        
        // Act
        let events = await generator.generateEvents(items: items)
        
        // Assert
        #expect(events.count == 4) // window/meta + fullSnapshot + viewport + drawImage
        #expect(events[0].type == .Meta)
        #expect(events[1].type == .FullSnapshot)
        #expect(events[2].type == .Custom)
        #expect(events[3].type == .IncrementalSnapshot) // drawImageEvent
    }
    
    @Test("Appends full snapshot when canvas buffer limit exceeded")
    func appendsFullSnapshotWhenCanvasBufferLimitExceeded() async {
        // Arrange
        let generator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Test",
            method: .overlayTiles()
        )
        
        // Choose a first image whose base64 string length will exceed the canvasBufferLimit (~10MB)
        // Base64 inflates ~4/3, so ~8MB raw data is sufficient.
        let largeFirstImage = makeExportFrame(dataSize: 8_000_000, width: 320, height: 480, timestamp: 1.0)
        let secondImageSameSize = makeExportFrame(dataSize: 256, width: 320, height: 480, timestamp: 2.0)
        
        let items: [EventQueueItem] = [
            EventQueueItem(payload: ImageItemPayload(exportFrame: largeFirstImage)),
            EventQueueItem(payload: ImageItemPayload(exportFrame: secondImageSameSize))
        ]
        
        // Act
        let events = await generator.generateEvents(items: items)
        
        // Assert
        #expect(events.count == 6) // two full snapshots (window/meta + fullSnapshot + viewport)
        #expect(events[0].type == .Meta)
        #expect(events[1].type == .FullSnapshot)
        #expect(events[2].type == .Custom)
        #expect(events[3].type == .Meta)
        #expect(events[4].type == .FullSnapshot)
        #expect(events[5].type == .Custom)
    }
    
    @Test("Appends mutation when canvas buffer limit exceeded for non-keyframe")
    func appendsMutationWhenCanvasBufferLimitExceededForNonKeyframe() async {
        // Arrange
        let generator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Test",
            method: .overlayTiles()
        )
        
        // First keyframe exceeds buffer limit. Second frame is not a keyframe,
        // so it should still use addCommandNodes per line-124 condition.
        let keyframeImage = makeExportFrame(
            dataSize: 8_000_000,
            width: 320,
            height: 480,
            timestamp: 1.0,
            keyFrameId: 1,
            isKeyframe: true
        )
        let nonKeyframeImage = makeExportFrame(
            dataSize: 256,
            width: 320,
            height: 480,
            timestamp: 2.0,
            keyFrameId: 1,
            isKeyframe: false
        )
        
        let items: [EventQueueItem] = [
            EventQueueItem(payload: ImageItemPayload(exportFrame: keyframeImage)),
            EventQueueItem(payload: ImageItemPayload(exportFrame: nonKeyframeImage))
        ]
        
        // Act
        let events = await generator.generateEvents(items: items)
        
        // Assert
        #expect(events.count == 4) // full snapshot events + one mutation event
        #expect(events[0].type == .Meta)
        #expect(events[1].type == .FullSnapshot)
        #expect(events[2].type == .Custom)
        #expect(events[3].type == .IncrementalSnapshot)
    }
    
    @Test("Appends RemoteControl custom event for non-keyboard press interaction")
    func appendsRemoteControlCustomEvent() async throws {
        let generator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Test",
            method: .overlayTiles()
        )
        let pressInteraction = PressInteraction(
            phase: .began,
            kind: .select,
            timestamp: 99.0,
            target: nil,
            isKeyboardOriginated: false
        )
        let items: [EventQueueItem] = [EventQueueItem(payload: TVPressInteractionPayload(pressInteraction: pressInteraction))]
        let events = await generator.generateEvents(items: items)
        #expect(events.count == 1)
        #expect(events[0].type == .Custom)
        let encoded = try JSONEncoder().encode(events[0])
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        let data = json?["data"] as? [String: Any]
        #expect(data?["tag"] as? String == "RemoteControl")
        let payload = data?["payload"] as? [String: Any]
        #expect(payload?["phase"] as? String == "began")
        #expect(payload?["pressType"] as? String == "select")
        #expect(payload?["pressTypeSystemRaw"] == nil)
    }
    
    @Test("Appends Keyboard custom event when press is keyboard-originated")
    func appendsKeyboardPressCustomEvent() async throws {
        let generator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Test",
            method: .overlayTiles()
        )
        let pressInteraction = PressInteraction(
            phase: .ended,
            kind: .select,
            timestamp: 12.0,
            target: nil,
            isKeyboardOriginated: true
        )
        let items: [EventQueueItem] = [EventQueueItem(payload: TVPressInteractionPayload(pressInteraction: pressInteraction))]
        let events = await generator.generateEvents(items: items)
        #expect(events.count == 1)
        #expect(events[0].type == .Custom)
        let encoded = try JSONEncoder().encode(events[0])
        let json = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        let data = json?["data"] as? [String: Any]
        #expect(data?["tag"] as? String == "Keyboard")
        let payload = data?["payload"] as? [String: Any]
        #expect(payload?["phase"] as? String == "ended")
    }
    
    @Test("RemoteControl custom event decodes via AnyEventData")
    func remoteControlEventDecodesRoundTrip() throws {
        let payload = RemoteControlPayload(phase: "began", pressType: "other", pressTypeSystemRaw: 77)
        let custom = CustomEventData(tag: .remoteControl, payload: payload)
        let event = Event(type: .Custom, data: AnyEventData(custom), timestamp: 10.0, _sid: 1)
        let encoded = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(Event.self, from: encoded)
        #expect(decoded.type == .Custom)
        let roundTrip = try JSONEncoder().encode(decoded)
        let json = try JSONSerialization.jsonObject(with: roundTrip) as? [String: Any]
        let data = json?["data"] as? [String: Any]
        #expect(data?["tag"] as? String == "RemoteControl")
        let p = data?["payload"] as? [String: Any]
        #expect(p?["pressTypeSystemRaw"] as? Int == 77)
    }
}

