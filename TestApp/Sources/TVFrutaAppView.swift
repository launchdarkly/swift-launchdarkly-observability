#if os(tvOS)

import SwiftUI

struct TVFrutaAppView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: FrutaItem?

    private let columns = [GridItem(.adaptive(minimum: 350), spacing: 50)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 50) {
                    ForEach(FrutaItem.all) { item in
                        TVFrutaCard(item: item) {
                            selectedItem = item
                        }
                    }
                }
                .padding(80)
            }
            .navigationTitle("Fruta Gallery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fullScreenCover(item: $selectedItem) { item in
                TVFrutaDetailView(item: item, allItems: FrutaItem.all)
            }
        }
    }
}

// MARK: - Card

private struct TVFrutaCard: View {
    let item: FrutaItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                item.gradient
                    .overlay {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(height: 250)
                    .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(item.subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .buttonStyle(.card)
    }
}

// MARK: - Detail

private struct TVFrutaDetailView: View {
    let item: FrutaItem
    let allItems: [FrutaItem]
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0

    var body: some View {
        ZStack {
            displayedItem.gradient
                .ignoresSafeArea()
                .opacity(0.4)

            VStack(spacing: 40) {
                Spacer()

                displayedItem.gradient
                    .overlay {
                        Image(systemName: displayedItem.systemImage)
                            .font(.system(size: 180))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(width: 600, height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 12) {
                    Text(displayedItem.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(displayedItem.subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }

                HStack(spacing: 32) {
                    Button {
                        withAnimation { navigatePrevious() }
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .disabled(currentIndex <= 0)

                    Text("\(currentIndex + 1) of \(allItems.count)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button {
                        withAnimation { navigateNext() }
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .disabled(currentIndex >= allItems.count - 1)
                }

                Spacer()

                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding(60)
        }
        .onAppear {
            currentIndex = allItems.firstIndex(where: { $0.id == item.id }) ?? 0
        }
    }

    private var displayedItem: FrutaItem {
        allItems[currentIndex]
    }

    private func navigatePrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func navigateNext() {
        guard currentIndex < allItems.count - 1 else { return }
        currentIndex += 1
    }
}

// MARK: - Data Model

struct FrutaItem: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let systemImage: String
    let gradientColors: [Color]

    var gradient: LinearGradient {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: FrutaItem, rhs: FrutaItem) -> Bool { lhs.id == rhs.id }

    static let all: [FrutaItem] = [
        FrutaItem(
            id: "strawberry",
            name: "Strawberry",
            subtitle: "Sweet and juicy summer berry",
            systemImage: "leaf.fill",
            gradientColors: [.red, .pink]
        ),
        FrutaItem(
            id: "banana",
            name: "Banana",
            subtitle: "Creamy tropical classic",
            systemImage: "moon.fill",
            gradientColors: [.yellow, .orange]
        ),
        FrutaItem(
            id: "blueberry",
            name: "Blueberry",
            subtitle: "Antioxidant-rich superfruit",
            systemImage: "circle.fill",
            gradientColors: [.indigo, .blue]
        ),
        FrutaItem(
            id: "mango",
            name: "Mango",
            subtitle: "The king of tropical fruits",
            systemImage: "sun.max.fill",
            gradientColors: [.orange, .yellow]
        ),
        FrutaItem(
            id: "kiwi",
            name: "Kiwi",
            subtitle: "Tangy green delight",
            systemImage: "circle.hexagongrid.fill",
            gradientColors: [.green, .mint]
        ),
        FrutaItem(
            id: "watermelon",
            name: "Watermelon",
            subtitle: "Refreshing summer staple",
            systemImage: "drop.fill",
            gradientColors: [.green, .red]
        ),
        FrutaItem(
            id: "coconut",
            name: "Coconut",
            subtitle: "Tropical hydration",
            systemImage: "circle.circle.fill",
            gradientColors: [.brown, .white.opacity(0.8)]
        ),
        FrutaItem(
            id: "pineapple",
            name: "Pineapple",
            subtitle: "Zesty tropical punch",
            systemImage: "crown.fill",
            gradientColors: [.yellow, .green]
        ),
        FrutaItem(
            id: "avocado",
            name: "Avocado",
            subtitle: "Creamy and nutritious",
            systemImage: "oval.fill",
            gradientColors: [.green, .brown]
        ),
        FrutaItem(
            id: "raspberry",
            name: "Raspberry",
            subtitle: "Tart and vibrant berry",
            systemImage: "heart.fill",
            gradientColors: [.pink, .purple]
        ),
        FrutaItem(
            id: "lemon",
            name: "Lemon",
            subtitle: "Bright citrus zing",
            systemImage: "sparkle",
            gradientColors: [.yellow, .green.opacity(0.6)]
        ),
        FrutaItem(
            id: "orange",
            name: "Orange",
            subtitle: "Classic citrus burst",
            systemImage: "sun.min.fill",
            gradientColors: [.orange, .red.opacity(0.7)]
        ),
    ]
}

#Preview {
    TVFrutaAppView()
}

#endif
