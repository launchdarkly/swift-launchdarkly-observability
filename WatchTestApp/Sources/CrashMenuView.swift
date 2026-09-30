import SwiftUI

struct CrashMenuView: View {
	@StateObject private var viewModel = CrashMenuViewModel()

	var body: some View {
		NavigationStack {
			List {
				scenario(
					title: "Flush + Kill 5s",
					caption: "Control: should arrive this launch",
					action: viewModel.evalTrackFlushThenKill
				)
				scenario(
					title: "Kill Now",
					caption: "SIGKILL, uncatchable: next launch only",
					action: viewModel.evalTrackThenKillNow
				)
				scenario(
					title: "Fatal Now",
					caption: "Swift trap: next launch only",
					action: viewModel.evalTrackThenFatalErrorNow
				)
			}
			.navigationTitle("Event Durability")
		}
	}

	private func scenario(title: String, caption: String, action: @escaping () -> Void) -> some View {
		Button(action: action) {
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.headline)
				Text(caption)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
		}
	}
}
