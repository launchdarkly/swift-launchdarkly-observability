import Testing
@testable import LaunchDarklySessionReplay
import LaunchDarklyObservability
import OSLog
import CoreGraphics
#if canImport(UIKit)
import UIKit

struct RawFramesRRWebEventGeneratorTests {
    private let screenSize = CGSize(width: 120, height: 88)

    @Test("Converts three raw frames into expected colored images")
    func convertsRawFramesIntoExpectedColors() async {
        let method: SessionReplayOptions.CompressionMethod = .overlayTiles(layers: 15, backtracking: false)
        let exportDiffManager = ExportDiffManager(compression: method, scale: 1.0)
        let eventGenerator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Benchmark",
            method: method
        )

        let frames: [RawFrame] = [
            makeRawFrame(color: .red, timestamp: 1.0),
            makeRawFrame(color: .green, timestamp: 2.0),
            makeRawFrame(color: .blue, timestamp: 3.0)
        ]

        var extractedColors = [UIColor]()
        var extractedSizes = [CGSize]()
        var extractedScales = [CGFloat]()

        for frame in frames {
            guard let exportFrame = exportDiffManager.exportFrame(from: frame) else {
                #expect(Bool(false), "Expected exportFrame for synthetic frame")
                continue
            }

            // Mirrors BenchmarkExecutor flow: exportFrame -> EventQueueItem -> generateEvents.
            let item = EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame))
            let events = await eventGenerator.generateEvents(items: [item])
            extractedColors.append(contentsOf: extractEventImageColors(events: events))
            extractedSizes.append(contentsOf: extractEventImageSizes(events: events))
        }

        #expect(extractedColors.count == 3)
        #expect(isDominatedByRed(extractedColors[0]))
        #expect(isDominatedByGreen(extractedColors[1]))
        #expect(isDominatedByBlue(extractedColors[2]))
        #expect(extractedSizes.count == 3)
        if let firstSize = extractedSizes.first {
            #expect(firstSize == screenSize)
            #expect(extractedSizes.allSatisfy { $0 == firstSize })
        }
    }

    @Test("Backtracking emits smaller add and remove-only rollback")
    func backtrackingEmitsSmallerAddAndRemoveOnlyRollback() async {
        let method: SessionReplayOptions.CompressionMethod = .overlayTiles(layers: 15, backtracking: true)
        let exportDiffManager = ExportDiffManager(compression: method, scale: 1.0)
        let eventGenerator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Benchmark",
            method: method
        )

        let baseFrame = makeRawFrame(color: .blue, timestamp: 1.0)
        let navBarFrame = makeRawFrameWithTopBar(baseColor: .blue, topBarColor: .red, topBarHeight: 22, timestamp: 2.0)
        let rollbackFrame = makeRawFrame(color: .blue, timestamp: 3.0)

        guard let exportFrame1 = exportDiffManager.exportFrame(from: baseFrame) else {
            #expect(Bool(false), "Expected export frame for base frame")
            return
        }
        let events1 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame1))])

        guard let exportFrame2 = exportDiffManager.exportFrame(from: navBarFrame) else {
            #expect(Bool(false), "Expected export frame for nav bar frame")
            return
        }
        let events2 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame2))])

        guard let exportFrame3 = exportDiffManager.exportFrame(from: rollbackFrame) else {
            #expect(Bool(false), "Expected export frame for rollback frame")
            return
        }
        let events3 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame3))])

        let firstSize = firstAddedImageSize(events: events1)
        let secondSize = firstAddedImageSize(events: events2)
        #expect(firstSize != nil)
        #expect(secondSize != nil)
        if let firstSize, let secondSize {
            #expect(firstSize == screenSize)
            #expect(secondSize.width == firstSize.width)
            #expect(secondSize.height < firstSize.height)
        }

        guard let thirdMutation = firstMutationData(events: events3) else {
            #expect(Bool(false), "Expected mutation event for rollback frame")
            return
        }
        #expect(thirdMutation.adds.isEmpty)
        #expect(!thirdMutation.removes.isEmpty)
        let secondAddedIds = addedNodeIds(events: events2)
        let thirdRemovedIds = Set(thirdMutation.removes.map(\.id))
        #expect(!secondAddedIds.isEmpty)
        #expect(thirdRemovedIds == Set(secondAddedIds))
    }

    @Test("Backtracking across top and bottom bars supports two rollbacks")
    func backtrackingAcrossTopAndBottomBarsSupportsTwoRollbacks() async {
        let method: SessionReplayOptions.CompressionMethod = .overlayTiles(layers: 15, backtracking: true)
        let exportDiffManager = ExportDiffManager(compression: method, scale: 1.0)
        let eventGenerator = RRWebEventGenerator(
            log: OSLog(subsystem: "test", category: "test"),
            title: "Benchmark",
            method: method
        )

        let frame1 = makeRawFrame(color: .blue, timestamp: 1.0)
        let frame2 = makeRawFrameWithTopBar(baseColor: .blue, topBarColor: .green, topBarHeight: 22, timestamp: 2.0)
        let frame3 = makeRawFrameWithTopAndBottomBars(
            baseColor: .blue,
            topBarColor: .green,
            topBarHeight: 22,
            bottomBarColor: .green,
            bottomBarHeight: 22,
            timestamp: 3.0
        )
        // Reuse the same underlying image buffers to guarantee identical signatures for backtracking.
        let frame4 = RawFrame(image: frame2.image, timestamp: 4.0, orientation: frame2.orientation, areas: frame2.areas)
        let frame5 = RawFrame(image: frame1.image, timestamp: 5.0, orientation: frame1.orientation, areas: frame1.areas)

        guard let exportFrame1 = exportDiffManager.exportFrame(from: frame1) else {
            #expect(Bool(false), "Expected export frame for frame 1")
            return
        }
        let events1 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame1))])

        guard let exportFrame2 = exportDiffManager.exportFrame(from: frame2) else {
            #expect(Bool(false), "Expected export frame for frame 2")
            return
        }
        let events2 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame2))])

        guard let exportFrame3 = exportDiffManager.exportFrame(from: frame3) else {
            #expect(Bool(false), "Expected export frame for frame 3")
            return
        }
        let events3 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame3))])

        guard let exportFrame4 = exportDiffManager.exportFrame(from: frame4) else {
            #expect(Bool(false), "Expected export frame for frame 4")
            return
        }
        let events4 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame4))])

        guard let exportFrame5 = exportDiffManager.exportFrame(from: frame5) else {
            #expect(Bool(false), "Expected export frame for frame 5")
            return
        }
        let events5 = await eventGenerator.generateEvents(items: [EventQueueItem(payload: ImageItemPayload(exportFrame: exportFrame5))])

        let firstSize = firstAddedImageSize(events: events1)
        let secondSize = firstAddedImageSize(events: events2)
        let thirdSize = firstAddedImageSize(events: events3)
        #expect(firstSize != nil)
        #expect(secondSize != nil)
        #expect(thirdSize != nil)
        if let firstSize, let secondSize, let thirdSize {
            #expect(firstSize == screenSize)
            #expect(secondSize.width == firstSize.width)
            #expect(secondSize.height < firstSize.height)
            #expect(thirdSize.width == firstSize.width)
            #expect(thirdSize.height < firstSize.height)
        }

        guard let fourthMutation = firstMutationData(events: events4) else {
            #expect(Bool(false), "Expected mutation event for frame 4")
            return
        }
        #expect(fourthMutation.adds.isEmpty)
        #expect(!fourthMutation.removes.isEmpty)
        let thirdAddedIds = addedNodeIds(events: events3)
        let fourthRemovedIds = Set(fourthMutation.removes.map(\.id))
        #expect(!thirdAddedIds.isEmpty)
        #expect(fourthRemovedIds == Set(thirdAddedIds))

        guard let fifthMutation = firstMutationData(events: events5) else {
            #expect(Bool(false), "Expected mutation event for frame 5")
            return
        }
        #expect(fifthMutation.adds.isEmpty)
        #expect(!fifthMutation.removes.isEmpty)
        let secondAddedIds = addedNodeIds(events: events2)
        let fifthRemovedIds = Set(fifthMutation.removes.map(\.id))
        #expect(!secondAddedIds.isEmpty)
        #expect(fifthRemovedIds == Set(secondAddedIds))
    }

    private func makeRawFrame(color: UIColor, timestamp: TimeInterval) -> RawFrame {
        let renderer = UIGraphicsImageRenderer(size: screenSize, format: makeRendererFormat())
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: screenSize))
        }
        #expect(abs(image.scale - 1.0) < 0.0001)
        return RawFrame(image: image, timestamp: timestamp, orientation: 0, areas: [])
    }

    private func makeRawFrameWithTopBar(baseColor: UIColor,
                                        topBarColor: UIColor,
                                        topBarHeight: CGFloat,
                                        timestamp: TimeInterval) -> RawFrame {
        let renderer = UIGraphicsImageRenderer(size: screenSize, format: makeRendererFormat())
        let image = renderer.image { context in
            baseColor.setFill()
            context.fill(CGRect(origin: .zero, size: screenSize))
            topBarColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: screenSize.width, height: topBarHeight))
        }
        #expect(abs(image.scale - 1.0) < 0.0001)
        return RawFrame(image: image, timestamp: timestamp, orientation: 0, areas: [])
    }

    private func makeRawFrameWithBottomBar(baseColor: UIColor,
                                           bottomBarColor: UIColor,
                                           bottomBarHeight: CGFloat,
                                           timestamp: TimeInterval) -> RawFrame {
        let renderer = UIGraphicsImageRenderer(size: screenSize, format: makeRendererFormat())
        let image = renderer.image { context in
            baseColor.setFill()
            context.fill(CGRect(origin: .zero, size: screenSize))
            bottomBarColor.setFill()
            context.fill(CGRect(x: 0, y: screenSize.height - bottomBarHeight, width: screenSize.width, height: bottomBarHeight))
        }
        #expect(abs(image.scale - 1.0) < 0.0001)
        return RawFrame(image: image, timestamp: timestamp, orientation: 0, areas: [])
    }

    private func makeRawFrameWithTopAndBottomBars(baseColor: UIColor,
                                                  topBarColor: UIColor,
                                                  topBarHeight: CGFloat,
                                                  bottomBarColor: UIColor,
                                                  bottomBarHeight: CGFloat,
                                                  timestamp: TimeInterval) -> RawFrame {
        let renderer = UIGraphicsImageRenderer(size: screenSize, format: makeRendererFormat())
        let image = renderer.image { context in
            baseColor.setFill()
            context.fill(CGRect(origin: .zero, size: screenSize))
            topBarColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: screenSize.width, height: topBarHeight))
            bottomBarColor.setFill()
            context.fill(CGRect(x: 0, y: screenSize.height - bottomBarHeight, width: screenSize.width, height: bottomBarHeight))
        }
        #expect(abs(image.scale - 1.0) < 0.0001)
        return RawFrame(image: image, timestamp: timestamp, orientation: 0, areas: [])
    }

    private func extractEventImageColors(events: [Event]) -> [UIColor] {
        var colors = [UIColor]()
        for event in events {
            if let domData = event.data.value as? DomData {
                colors.append(contentsOf: colorsFromNodes(domData.node.childNodes))
            } else if let mutationData = event.data.value as? MutationData {
                for add in mutationData.adds {
                    if let color = colorFromDataURL(add.node.attributes?["src"]) {
                        colors.append(color)
                    }
                }
            }
        }
        return colors
    }

    private func extractEventImageSizes(events: [Event]) -> [CGSize] {
        var sizes = [CGSize]()
        for event in events {
            if let domData = event.data.value as? DomData {
                sizes.append(contentsOf: sizesFromNodes(domData.node.childNodes))
            } else if let mutationData = event.data.value as? MutationData {
                for add in mutationData.adds {
                    if let size = sizeFromNode(add.node) {
                        sizes.append(size)
                    }
                }
            }
        }
        return sizes
    }

    private func extractEventImageScales(events: [Event]) -> [CGFloat] {
        var scales = [CGFloat]()
        for event in events {
            if let domData = event.data.value as? DomData {
                scales.append(contentsOf: scalesFromNodes(domData.node.childNodes))
            } else if let mutationData = event.data.value as? MutationData {
                for add in mutationData.adds {
                    if let scale = imageScaleFromDataURL(add.node.attributes?["src"]) {
                        scales.append(scale)
                    }
                }
            }
        }
        return scales
    }

    private func firstAddedImageSize(events: [Event]) -> CGSize? {
        for event in events {
            if let domData = event.data.value as? DomData,
               let size = sizesFromNodes(domData.node.childNodes).first {
                return size
            }
            if let mutationData = event.data.value as? MutationData,
               let size = mutationData.adds.compactMap({ sizeFromNode($0.node) }).first {
                return size
            }
        }
        return nil
    }

    private func firstMutationData(events: [Event]) -> MutationData? {
        for event in events {
            if let mutationData = event.data.value as? MutationData {
                return mutationData
            }
        }
        return nil
    }

    private func addedNodeIds(events: [Event]) -> [Int] {
        var ids = [Int]()
        for event in events {
            if let domData = event.data.value as? DomData {
                ids.append(contentsOf: imageNodeIdsFromNodes(domData.node.childNodes))
            } else if let mutationData = event.data.value as? MutationData {
                ids.append(contentsOf: mutationData.adds.compactMap(\.node.id))
            }
        }
        return ids
    }

    private func colorsFromNodes(_ nodes: [EventNode]) -> [UIColor] {
        var colors = [UIColor]()
        for node in nodes {
            if node.tagName == "img", let color = colorFromDataURL(node.attributes?["src"]) {
                colors.append(color)
            }
            colors.append(contentsOf: colorsFromNodes(node.childNodes))
        }
        return colors
    }
    
    private func imageNodeIdsFromNodes(_ nodes: [EventNode]) -> [Int] {
        var ids = [Int]()
        for node in nodes {
            if node.tagName == "img", let id = node.id {
                ids.append(id)
            }
            ids.append(contentsOf: imageNodeIdsFromNodes(node.childNodes))
        }
        return ids
    }

    private func sizesFromNodes(_ nodes: [EventNode]) -> [CGSize] {
        var sizes = [CGSize]()
        for node in nodes {
            if let size = sizeFromNode(node) {
                sizes.append(size)
            }
            sizes.append(contentsOf: sizesFromNodes(node.childNodes))
        }
        return sizes
    }

    private func scalesFromNodes(_ nodes: [EventNode]) -> [CGFloat] {
        var scales = [CGFloat]()
        for node in nodes {
            if node.tagName == "img", let scale = imageScaleFromDataURL(node.attributes?["src"]) {
                scales.append(scale)
            }
            scales.append(contentsOf: scalesFromNodes(node.childNodes))
        }
        return scales
    }

    private func sizeFromNode(_ node: EventNode) -> CGSize? {
        guard node.tagName == "img",
              let attributes = node.attributes,
              let widthString = attributes["width"],
              let heightString = attributes["height"],
              let width = Double(widthString),
              let height = Double(heightString) else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    private func colorFromDataURL(_ dataURL: String?) -> UIColor? {
        guard let dataURL,
              let commaIndex = dataURL.firstIndex(of: ",") else {
            return nil
        }
        let base64 = String(dataURL[dataURL.index(after: commaIndex)...])
        guard let imageData = Data(base64Encoded: base64),
              let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let x = max(0, min(width - 1, width / 2))
        let y = max(0, min(height - 1, height / 2))

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: CGFloat(-x), y: CGFloat(y - height + 1))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return UIColor(
            red: CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue: CGFloat(pixel[2]) / 255.0,
            alpha: CGFloat(pixel[3]) / 255.0
        )
    }

    private func imageScaleFromDataURL(_ dataURL: String?) -> CGFloat? {
        guard let dataURL,
              let commaIndex = dataURL.firstIndex(of: ",") else {
            return nil
        }
        let base64 = String(dataURL[dataURL.index(after: commaIndex)...])
        guard let imageData = Data(base64Encoded: base64),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image.scale
    }

    private func makeRendererFormat() -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        return format
    }

    private func rgba(_ color: UIColor) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    private func isDominatedByRed(_ color: UIColor) -> Bool {
        let channels = rgba(color)
        return channels.r > 0.7 && channels.g < 0.35 && channels.b < 0.35
    }

    private func isDominatedByGreen(_ color: UIColor) -> Bool {
        let channels = rgba(color)
        return channels.g > 0.7 && channels.r < 0.35 && channels.b < 0.35
    }

    private func isDominatedByBlue(_ color: UIColor) -> Bool {
        let channels = rgba(color)
        return channels.b > 0.7 && channels.r < 0.35 && channels.g < 0.35
    }
}
#endif
