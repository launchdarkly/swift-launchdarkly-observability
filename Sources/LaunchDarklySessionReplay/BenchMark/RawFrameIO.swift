#if canImport(UIKit)

import UIKit
import Foundation

final class RawFrameWriter {
    let directory: URL
    private var frameIndex: Int = 0
    private var imageIndex: Int = 0
    private var lastImageData: Data?
    private let csvHandle: FileHandle

    init() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RawFrames-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.directory = dir
        print("RawFrameWriter: directory = \(dir)")
        let csvURL = dir.appendingPathComponent("frames.csv")
        FileManager.default.createFile(atPath: csvURL.path, contents: nil)
        self.csvHandle = try FileHandle(forWritingTo: csvURL)

        let header = "frameIndex,imageIndex,timestamp,orientation,areas\n"
        csvHandle.write(Data(header.utf8))
    }

    deinit {
        try? csvHandle.close()
    }

    func write(rawFrame: RawFrame) throws {
        let index = frameIndex
        frameIndex += 1

        guard let pngData = rawFrame.image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }

        let currentImageIndex: Int
        if pngData == lastImageData {
            currentImageIndex = imageIndex - 1
        } else {
            currentImageIndex = imageIndex
            let imageURL = directory.appendingPathComponent(String(format: "%06d.png", currentImageIndex))
            try pngData.write(to: imageURL)
            lastImageData = pngData
            imageIndex += 1
        }

        let areasArray: [[String: [String: CGFloat]]] = rawFrame.areas.map { area in
            [
                "rect": [
                    "x": area.rect.origin.x,
                    "y": area.rect.origin.y,
                    "width": area.rect.size.width,
                    "height": area.rect.size.height
                ],
                "offset": [
                    "x": area.offset.x,
                    "y": area.offset.y
                ]
            ]
        }
        let areasData = try JSONSerialization.data(withJSONObject: areasArray)
        let areasJSON = String(data: areasData, encoding: .utf8) ?? "[]"
        let escapedAreas = areasJSON.replacingOccurrences(of: "\"", with: "\"\"")

        let row = "\(index),\(currentImageIndex),\(rawFrame.timestamp),\(rawFrame.orientation),\"\(escapedAreas)\"\n"
        csvHandle.write(Data(row.utf8))
    }
}

#endif
