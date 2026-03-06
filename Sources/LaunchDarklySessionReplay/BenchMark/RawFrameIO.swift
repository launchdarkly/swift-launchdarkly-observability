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

// MARK: - RawFrameReader

final class RawFrameReader: Sequence {
    private let directory: URL
    private let rows: [String]

    init(directory: URL) throws {
        self.directory = directory
        let csvURL = directory.appendingPathComponent("frames.csv")
        let content = try String(contentsOf: csvURL, encoding: .utf8)
        self.rows = content.components(separatedBy: "\n")
            .dropFirst()
            .filter { !$0.isEmpty }
    }

    func makeIterator() -> Iterator {
        Iterator(directory: directory, rows: rows)
    }

    struct Iterator: IteratorProtocol {
        private let directory: URL
        private let rows: [String]
        private var index = 0
        private var imageCache = [Int: UIImage]()

        init(directory: URL, rows: [String]) {
            self.directory = directory
            self.rows = rows
        }

        mutating func next() -> RawFrame? {
            guard index < rows.count else { return nil }
            defer { index += 1 }
            return parse(line: rows[index])
        }

        private mutating func parse(line: String) -> RawFrame? {
            let columns = Self.parseCSV(line: line)
            guard columns.count >= 5,
                  let imageIndex = Int(columns[1]),
                  let timestamp = TimeInterval(columns[2]),
                  let orientation = Int(columns[3])
            else { return nil }

            let image: UIImage
            if let cached = imageCache[imageIndex] {
                image = cached
            } else {
                let imageURL = directory.appendingPathComponent(String(format: "%06d.png", imageIndex))
                guard let loaded = UIImage(contentsOfFile: imageURL.path),
                      let decoded = Self.forceDecoded(loaded) else { return nil }
                imageCache[imageIndex] = decoded
                image = decoded
            }

            let areasJSON = columns[4].replacingOccurrences(of: "\"\"", with: "\"")
            var areas = [OffsettedArea]()
            if let data = areasJSON.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [[String: [String: CGFloat]]] {
                for dict in array {
                    guard let r = dict["rect"], let o = dict["offset"],
                          let x = r["x"], let y = r["y"], let w = r["width"], let h = r["height"],
                          let ox = o["x"], let oy = o["y"]
                    else { continue }
                    areas.append(OffsettedArea(
                        rect: CGRect(x: x, y: y, width: w, height: h),
                        offset: CGPoint(x: ox, y: oy)
                    ))
                }
            }

            return RawFrame(image: image, timestamp: timestamp, orientation: orientation, areas: areas)
        }

        private static func forceDecoded(_ source: UIImage) -> UIImage? {
            guard let cgImage = source.cgImage else { return nil }
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return nil }
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            guard let decoded = ctx.makeImage() else { return nil }
            return UIImage(cgImage: decoded, scale: source.scale, orientation: source.imageOrientation)
        }

        private static func parseCSV(line: String) -> [String] {
            var result = [String]()
            var current = ""
            var inQuotes = false
            for ch in line {
                if ch == "\"" {
                    inQuotes.toggle()
                } else if ch == "," && !inQuotes {
                    result.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
            result.append(current)
            return result
        }
    }
}

#endif
