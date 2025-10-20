import SwiftUI
import Combine

struct OverlayCanvasView: View {
    @StateObject private var model: OverlayCanvasModel
    @State private var isDragging: Bool = false

    init(trailRetentionSeconds: TimeInterval = 1.8,
         maximumBrushPoints: Int = 400,
         minimumPointDistance: CGFloat = 2) {
        _model = StateObject(wrappedValue: OverlayCanvasModel(
            trailRetentionSeconds: trailRetentionSeconds,
            maximumBrushPoints: maximumBrushPoints,
            minimumPointDistance: minimumPointDistance
        ))
    }

    var body: some View {
        Canvas { context, size in
            let now = Date()

            // 1) Brush trail
            if model.brushPoints.count > 1 {
                let points = model.brushPoints
                for index in 1..<points.count {
                    let previous = points[index - 1]
                    let current = points[index]

                    let jump = hypot(current.point.x - previous.point.x, current.point.y - previous.point.y)
                    if jump > 200 { continue }

                    var path = Path()
                    path.move(to: previous.point)
                    path.addLine(to: current.point)

                    let age = now.timeIntervalSince(current.time)
                    let life = max(0, 1 - age / model.trailRetentionSeconds)
                    guard life > 0 else { continue }

                    let alpha = life * 0.9
                    let width = 8 * (0.6 + 0.4 * life)
                    let style = StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                    context.stroke(path, with: .color(current.color.opacity(alpha)), style: style)
                }
            }

            // 2) Active touch down (no fade while dragging)
            if let active = model.activeTouchDown {
                let radius = model.downBaseRadius
                let rect = CGRect(
                    x: active.point.x - radius,
                    y: active.point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                let gradient = Gradient(stops: [
                    .init(color: Color.black.opacity(0.35), location: 0.0),
                    .init(color: Color.black.opacity(0.0), location: 1.0)
                ])
                let shading = GraphicsContext.Shading.radialGradient(
                    gradient,
                    center: active.point,
                    startRadius: 0,
                    endRadius: radius
                )
                context.fill(Path(ellipseIn: rect), with: shading)
            }

            // 3) Fading touch down spots (after lift)
            if !model.touchDownSpots.isEmpty {
                for spot in model.touchDownSpots {
                    let age = now.timeIntervalSince(spot.time)
                    let life = max(0, 1 - age / model.downRetentionSeconds)
                    guard life > 0 else { continue }

                    let radius = model.downBaseRadius * (0.7 + 0.3 * life)
                    let rect = CGRect(
                        x: spot.point.x - radius,
                        y: spot.point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    let gradient = Gradient(stops: [
                        .init(color: Color.black.opacity(0.35 * life), location: 0.0),
                        .init(color: Color.black.opacity(0.0), location: 1.0)
                    ])
                    let shading = GraphicsContext.Shading.radialGradient(
                        gradient,
                        center: spot.point,
                        startRadius: 0,
                        endRadius: radius
                    )
                    context.fill(Path(ellipseIn: rect), with: shading)
                }
            }

            // 4) Touch up circles with thin cross, random color per circle
            if !model.touchUpCircles.isEmpty {
                for mark in model.touchUpCircles {
                    let age = now.timeIntervalSince(mark.time)
                    let life = max(0, 1 - age / model.upRetentionSeconds)
                    guard life > 0 else { continue }

                    let radius = model.upBaseRadius
                    // Outer circle
                    let circleRect = CGRect(
                        x: mark.point.x - radius,
                        y: mark.point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    let circlePath = Path(ellipseIn: circleRect)
                    let strokeStyle = StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
                    context.stroke(circlePath, with: .color(mark.color.opacity(0.9 * life)), style: strokeStyle)

                    // Thin cross
                    var cross = Path()
                    let crossLen = radius * 0.6
                    cross.move(to: CGPoint(x: mark.point.x - crossLen, y: mark.point.y))
                    cross.addLine(to: CGPoint(x: mark.point.x + crossLen, y: mark.point.y))
                    cross.move(to: CGPoint(x: mark.point.x, y: mark.point.y - crossLen))
                    cross.addLine(to: CGPoint(x: mark.point.x, y: mark.point.y + crossLen))
                    context.stroke(cross, with: .color(mark.color.opacity(0.9 * life)), style: StrokeStyle(lineWidth: 1.0))
                }
            }
        }
        .contentShape(Rectangle())
#if os(iOS)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        model.registerTouchDown(at: value.location)
                    }
                    model.updateActiveTouchDown(point: value.location)
                    model.append(point: value.location)
                    model.prune()
                }
                .onEnded { value in
                    model.registerTouchUp(at: value.location)
                    model.finalizeTouchDown()
                    isDragging = false
                }
        )
#endif
        .onReceive(model.decayTimer) { _ in
            model.prune()
        }
    }
}

final class OverlayCanvasModel: ObservableObject {
    struct BrushPoint {
        let point: CGPoint
        let time: Date
        let color: Color
    }

    struct TouchDownSpot {
        let point: CGPoint
        let time: Date
    }

    struct TouchUpCircle {
        let point: CGPoint
        let time: Date
        let color: Color
    }

    @Published var brushPoints: [BrushPoint] = []
    @Published var activeTouchDown: TouchDownSpot? = nil
    @Published var touchDownSpots: [TouchDownSpot] = []
    @Published var touchUpCircles: [TouchUpCircle] = []
    @Published private(set) var currentStrokeColor: Color? = nil

    // Configuration
    let trailRetentionSeconds: TimeInterval
    let maximumBrushPoints: Int
    let minimumPointDistance: CGFloat
    let downRetentionSeconds: TimeInterval
    let upRetentionSeconds: TimeInterval
    let downBaseRadius: CGFloat
    let upBaseRadius: CGFloat

    // Timer publisher to drive decay
    let decayTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    init(trailRetentionSeconds: TimeInterval = 1.8,
         maximumBrushPoints: Int = 400,
         minimumPointDistance: CGFloat = 2,
         downRetentionSeconds: TimeInterval = 0.6,
         upRetentionSeconds: TimeInterval = 6.4,
         downBaseRadius: CGFloat = 40,
         upBaseRadius: CGFloat = 22) {
        self.trailRetentionSeconds = trailRetentionSeconds
        self.maximumBrushPoints = maximumBrushPoints
        self.minimumPointDistance = minimumPointDistance
        self.downRetentionSeconds = downRetentionSeconds
        self.upRetentionSeconds = upRetentionSeconds
        self.downBaseRadius = downBaseRadius
        self.upBaseRadius = upBaseRadius
    }

    func append(point: CGPoint, at time: Date = Date()) {
        if let last = brushPoints.last {
            let dx = point.x - last.point.x
            let dy = point.y - last.point.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance < minimumPointDistance { return }
        }
        let color = currentStrokeColor ?? Self.randomHighContrastColor()
        currentStrokeColor = color
        brushPoints.append(BrushPoint(point: point, time: time, color: color))
        if brushPoints.count > maximumBrushPoints {
            brushPoints.removeFirst(brushPoints.count - maximumBrushPoints)
        }
    }

    func prune(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-trailRetentionSeconds)
        if let firstValidIndex = brushPoints.firstIndex(where: { $0.time >= cutoff }) {
            if firstValidIndex > 0 {
                brushPoints.removeFirst(firstValidIndex)
            }
        } else {
            brushPoints.removeAll(keepingCapacity: true)
        }

        // Prune touch down spots
        let downCutoff = now.addingTimeInterval(-downRetentionSeconds)
        if let firstValidIndex = touchDownSpots.firstIndex(where: { $0.time >= downCutoff }) {
            if firstValidIndex > 0 {
                touchDownSpots.removeFirst(firstValidIndex)
            }
        } else {
            touchDownSpots.removeAll(keepingCapacity: true)
        }

        // Prune touch up circles
        let upCutoff = now.addingTimeInterval(-upRetentionSeconds)
        if let firstValidIndex = touchUpCircles.firstIndex(where: { $0.time >= upCutoff }) {
            if firstValidIndex > 0 {
                touchUpCircles.removeFirst(firstValidIndex)
            }
        } else {
            touchUpCircles.removeAll(keepingCapacity: true)
        }
    }

    func registerTouchDown(at point: CGPoint, time: Date = Date()) {
        activeTouchDown = TouchDownSpot(point: point, time: time)
        if currentStrokeColor == nil {
            currentStrokeColor = Self.randomHighContrastColor()
        }
    }

    func registerTouchUp(at point: CGPoint, time: Date = Date()) {
        let color = currentStrokeColor ?? Self.randomHighContrastColor()
        touchUpCircles.append(TouchUpCircle(point: point, time: time, color: color))
        if touchUpCircles.count > 100 { touchUpCircles.removeFirst(touchUpCircles.count - 100) }
    }

    func finalizeTouchDown(time: Date = Date()) {
        if let active = activeTouchDown {
            touchDownSpots.append(TouchDownSpot(point: active.point, time: time))
            if touchDownSpots.count > 100 { touchDownSpots.removeFirst(touchDownSpots.count - 100) }
        }
        activeTouchDown = nil
        currentStrokeColor = nil
    }

    func updateActiveTouchDown(point: CGPoint, time: Date = Date()) {
        if activeTouchDown != nil {
            activeTouchDown = TouchDownSpot(point: point, time: time)
        }
    }

    private static func randomHighContrastColor() -> Color {
        let hue = Double.random(in: 0...1)
        let saturation = Double.random(in: 0.75...0.95)
        let brightness = Double.random(in: 0.75...0.95)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}


