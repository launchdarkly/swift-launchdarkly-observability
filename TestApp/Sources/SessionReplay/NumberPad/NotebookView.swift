#if os(iOS)

import SwiftUI

struct NotebookView: View {
    private let gridSpacing: CGFloat = 24
    private let lineWidth: CGFloat = 0.5
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // Squared notebook background
                    Canvas { context, size in
                        let cols = Int(ceil(size.width / gridSpacing))
                        let rows = Int(ceil(size.height / gridSpacing))

                        var path = Path()
                        for c in 0...cols {
                            let x = CGFloat(c) * gridSpacing
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for r in 0...rows {
                            let y = CGFloat(r) * gridSpacing
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        let color = Color.secondary.opacity(0.25)
                        let style = StrokeStyle(lineWidth: lineWidth)
                        context.stroke(path, with: .color(color), style: style)
                    }
                    .background(Color(.systemBackground))

                    // Brush overlay
                    OverlayCanvasView()
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Notebook (SwiftUI)")
            .toolbar {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                }
                SnapshotButton()
            }
        }
    }
}

#Preview {
    NotebookView()
}


#endif
