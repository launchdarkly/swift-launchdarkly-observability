import SwiftUI

struct NumberPatternGrid: View {
    var onActivate: ([Int]) -> Void

    @State private var dragSequence: [Int] = []
    @State private var frames: [Int: CGRect] = [:]
    @State private var pressedNumber: Int? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)

    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(1...25, id: \.self) { number in
                    NumberCell(
                        number: number,
                        isSelected: dragSequence.contains(number),
                        isPressed: pressedNumber == number
                    )
                    .overlay(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: ButtonFramePreferenceKey.self,
                                        value: [number: geo.frame(in: .named("gridSpace"))]
                                    )
                            }
                        )
                }
            }
            .padding(16)
        }
        .coordinateSpace(name: "gridSpace")
        .onPreferenceChange(ButtonFramePreferenceKey.self) { newValue in
            frames = newValue
        }
#if os(iOS)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if let hit = frames.first(where: { $0.value.contains(value.location) })?.key {
                        // Update pressed visual state immediately on touch-down or move
                        if pressedNumber != hit {
                            pressedNumber = hit
                        }
                        // Append to sequence if first time hitting this number
                        if !dragSequence.contains(hit) {
                            dragSequence.append(hit)
                        }
                    } else {
                        // Finger moved outside any circle, clear pressed state
                        if pressedNumber != nil {
                            pressedNumber = nil
                        }
                    }
                }
                .onEnded { _ in
                    guard !dragSequence.isEmpty else { return }
                    onActivate(dragSequence)
                    dragSequence.removeAll()
                    pressedNumber = nil
                }
        )
#endif
    }
}

private struct NumberCell: View {
    let number: Int
    let isSelected: Bool
    let isPressed: Bool
#if os(iOS)
    let unselectedFillColor = Color(.systemGray6)
    let unselectedCircleColor = Color(.systemGray3)
#else
    let unselectedFillColor = Color.gray.opacity(0.3)
    let unselectedCircleColor = Color.gray.opacity(0.5)
#endif
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor.opacity(0.2) : unselectedFillColor)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : unselectedCircleColor, lineWidth: 2)
                )

            Text("\(number)")
                .font(.title2.weight(.semibold))
                .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Circle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .accessibilityIdentifier("\(number)")
    }
}

private struct ButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
