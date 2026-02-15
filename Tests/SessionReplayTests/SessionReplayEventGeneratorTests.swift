import Testing
@testable import LaunchDarklySessionReplay
import LaunchDarklyObservability
import OSLog
import CoreGraphics

struct RRWebEventGeneratorTests {
    
    private func makeExportFrame(dataSize: Int, width: Int, height: Int, timestamp: TimeInterval) -> ExportFrame {
        let data = Data(count: dataSize)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let exportedFrame = ExportFrame.ExportImage(data: data, dataHashValue: data.hashValue, rect: rect)
        return ExportFrame(
            images: [exportedFrame],
            originalSize: CGSize(width: width, height: height),
            scale: 1.0,
            format: .png,
            timestamp: timestamp,
            orientation: 0,
            isKeyframe: true
        )
    }
    
    @Test("Appends draw image event when same size and below limit")
    func appendsDrawImageEventWhenSameSizeAndBelowLimit() async {
        // Arrange
        let generator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Test"
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
            title: "Test"
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
}

