import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var foregroundUptime: TimeInterval?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = CatsOverviewViewController()
        window.backgroundColor = .white
        self.window = window
        window.makeKeyAndVisible()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        foregroundUptime = ProcessInfo.processInfo.systemUptime
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        let activateUptime = ProcessInfo.processInfo.systemUptime
        if let foregroundUptime {
            SceneLaunchEventLog.shared.record(
                sceneID: scene.session.persistentIdentifier,
                foregroundUptime: foregroundUptime,
                activateUptime: activateUptime
            )
            self.foregroundUptime = nil
        }
        LaunchStatsOverlayView.install(in: window)
    }
}

// MARK: - Launch Stats Overlay

/// A floating panel added to each scene's window that shows all recorded launch events.
final class LaunchStatsOverlayView: UIView {
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    private var observer: NSObjectProtocol?

    static func install(in window: UIWindow?) {
        guard let window else { return }
        // Remove any existing overlay before adding a fresh one.
        window.subviews.compactMap { $0 as? LaunchStatsOverlayView }.forEach { $0.removeFromSuperview() }
        let overlay = LaunchStatsOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            overlay.trailingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            overlay.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.93)
        layer.cornerRadius = 12
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.separator.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: -2)

        titleLabel.text = "Launch Stats"
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel

        stackView.axis = .vertical
        stackView.spacing = 5
        stackView.addArrangedSubview(titleLabel)
        addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        refresh()

        observer = NotificationCenter.default.addObserver(
            forName: .sceneLaunchEventRecorded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func refresh() {
        stackView.arrangedSubviews.dropFirst().forEach { $0.removeFromSuperview() }

        let events = SceneLaunchEventLog.shared.events.suffix(5)
        if events.isEmpty {
            let label = UILabel()
            label.text = "No events yet"
            label.font = .systemFont(ofSize: 12)
            label.textColor = .tertiaryLabel
            stackView.addArrangedSubview(label)
            return
        }

        for event in events {
            stackView.addArrangedSubview(makeRow(for: event))
        }
    }

    private func makeRow(for event: SceneLaunchEvent) -> UIView {
        let badge = makeBadge(title: event.type.rawValue, color: event.type.color)

        let durationLabel = UILabel()
        durationLabel.text = String(format: "%.0f ms", event.durationMs)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        durationLabel.textColor = .label

        let sceneLabel = UILabel()
        sceneLabel.text = "scene: \(event.sceneID)"
        sceneLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        sceneLabel.textColor = .secondaryLabel
        sceneLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [badge, durationLabel, sceneLabel])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }

    private func makeBadge(title: String, color: UIColor) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = color
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: 96),
            label.heightAnchor.constraint(equalToConstant: 20)
        ])
        return label
    }
}
