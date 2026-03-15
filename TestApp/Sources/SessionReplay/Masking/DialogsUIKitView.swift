#if os(iOS)
import UIKit
import SwiftUI

final class DialogsUIKitViewController: UIViewController {

    private let windowPresenter = WindowSheetPresenter()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
        ])

        stack.addArrangedSubview(makeSectionLabel("Alerts"))
        stack.addArrangedSubview(makeButton("Simple Alert", action: #selector(showAlert)))
        stack.addArrangedSubview(makeButton("Action Sheet", action: #selector(showActionSheet)))

        stack.addArrangedSubview(makeSectionLabel("Bottom Sheets"))
        stack.addArrangedSubview(makeButton("Full Sheet", action: #selector(showFullSheet)))
        stack.addArrangedSubview(makeButton("Full Screen Cover", action: #selector(showFullScreenCover)))

        stack.addArrangedSubview(makeSectionLabel("Half Sheet"))
        stack.addArrangedSubview(makeSizingRow { [weak self] sizing in self?.showHalfSheetSizing(sizing) })

        stack.addArrangedSubview(makeSectionLabel("UIWindow Sizing"))
        stack.addArrangedSubview(makeSizingRow { [weak self] sizing in self?.showWindowSizing(sizing) })

        stack.addArrangedSubview(makeSectionLabel("Overlay"))
        stack.addArrangedSubview(makeButton("View Overlay", action: #selector(showViewOverlay)))
    }

    // MARK: - Helpers

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        return label
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeSizingRow(handler: @escaping (DimSizing) -> Void) -> UIStackView {
        let row = UIStackView(arrangedSubviews: DimSizing.allCases.map { sizing in
            var config = UIButton.Configuration.filled()
            config.title = sizing.rawValue
            config.buttonSize = .small
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
            return UIButton(configuration: config, primaryAction: UIAction { _ in handler(sizing) })
        })
        row.axis = .horizontal
        row.spacing = 6
        return row
    }

    // MARK: - Alerts

    @objc private func showAlert() {
        let alert = UIAlertController(
            title: "Alert",
            message: "This is an example alert dialog.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func showActionSheet() {
        let sheet = UIAlertController(title: "Actions", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Option A", style: .default))
        sheet.addAction(UIAlertAction(title: "Option B", style: .default))
        sheet.addAction(UIAlertAction(title: "Delete", style: .destructive))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(sheet, animated: true)
    }

    // MARK: - Bottom Sheets

    @objc private func showFullSheet() {
        let timerVC = CountdownTimerViewController()
        timerVC.onComplete = { [weak timerVC] in timerVC?.dismiss(animated: true) }
        timerVC.modalPresentationStyle = .pageSheet
        present(timerVC, animated: true)
    }

    @objc private func showFullScreenCover() {
        let timerVC = CountdownTimerViewController()
        timerVC.onComplete = { [weak timerVC] in
            timerVC?.navigationController?.dismiss(animated: true)
        }
        let nav = UINavigationController(rootViewController: timerVC)
        nav.modalPresentationStyle = .fullScreen
        timerVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: timerVC,
            action: #selector(CountdownTimerViewController.dismissSelf)
        )
        present(nav, animated: true)
    }

    // MARK: - Half Sheet (parameterized dim sizing)

    private func showHalfSheetSizing(_ sizing: DimSizing) {
        let viewBounds = view.bounds
        let oversizedFrame = sizing.dimFrame(for: viewBounds)

        let dimView = DismissableDimView(frame: oversizedFrame)

        let timerVC = CountdownTimerViewController()
        timerVC.view.translatesAutoresizingMaskIntoConstraints = false
        timerVC.view.backgroundColor = .systemBackground
        timerVC.view.layer.cornerRadius = 16
        timerVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        timerVC.view.clipsToBounds = true

        let cleanup: () -> Void = {
            timerVC.willMove(toParent: nil)
            timerVC.view.removeFromSuperview()
            timerVC.removeFromParent()
            dimView.removeFromSuperview()
        }

        timerVC.onComplete = cleanup
        dimView.onTap = cleanup

        addChild(timerVC)
        dimView.addSubview(timerVC.view)
        timerVC.didMove(toParent: self)

        let visibleX = -oversizedFrame.origin.x
        let visibleY = -oversizedFrame.origin.y

        NSLayoutConstraint.activate([
            timerVC.view.leadingAnchor.constraint(equalTo: dimView.leadingAnchor, constant: visibleX),
            timerVC.view.widthAnchor.constraint(equalToConstant: viewBounds.width),
            timerVC.view.topAnchor.constraint(equalTo: dimView.topAnchor, constant: visibleY + viewBounds.height / 2),
            timerVC.view.heightAnchor.constraint(equalToConstant: viewBounds.height / 2),
        ])

        view.addSubview(dimView)
    }

    // MARK: - UIWindow Sizing (parameterized dim sizing)

    private func showWindowSizing(_ sizing: DimSizing) {
        let screenBounds = UIScreen.main.bounds
        let windowFrame = sizing.dimFrame(for: screenBounds)

        let containerVC = UIViewController()
        containerVC.view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissWindowSheet))
        containerVC.view.addGestureRecognizer(tap)

        let timerVC = CountdownTimerViewController()
        timerVC.view.translatesAutoresizingMaskIntoConstraints = false
        timerVC.view.backgroundColor = .systemBackground
        timerVC.view.layer.cornerRadius = 16
        timerVC.view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        timerVC.view.clipsToBounds = true

        containerVC.addChild(timerVC)
        containerVC.view.addSubview(timerVC.view)
        timerVC.didMove(toParent: containerVC)

        let visibleX = -windowFrame.origin.x
        let visibleY = -windowFrame.origin.y

        NSLayoutConstraint.activate([
            timerVC.view.leadingAnchor.constraint(equalTo: containerVC.view.leadingAnchor, constant: visibleX),
            timerVC.view.widthAnchor.constraint(equalToConstant: screenBounds.width),
            timerVC.view.topAnchor.constraint(equalTo: containerVC.view.topAnchor, constant: visibleY + screenBounds.height / 2),
            timerVC.view.heightAnchor.constraint(equalToConstant: screenBounds.height / 2),
        ])

        timerVC.onComplete = { [weak self] in self?.windowPresenter.dismiss() }

        windowPresenter.presentViewController(containerVC, windowFrame: windowFrame)
    }

    @objc private func dismissWindowSheet() {
        windowPresenter.dismiss()
    }

    // MARK: - Overlay

    @objc private func showViewOverlay() {
        let dimView = DismissableDimView(frame: view.bounds)
        dimView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let timerVC = CountdownTimerViewController()
        timerVC.view.translatesAutoresizingMaskIntoConstraints = false
        timerVC.view.backgroundColor = .systemBackground
        timerVC.view.layer.cornerRadius = 16
        timerVC.view.clipsToBounds = true

        let cleanup: () -> Void = {
            timerVC.willMove(toParent: nil)
            timerVC.view.removeFromSuperview()
            timerVC.removeFromParent()
            dimView.removeFromSuperview()
        }

        timerVC.onComplete = cleanup
        dimView.onTap = cleanup

        addChild(timerVC)
        dimView.addSubview(timerVC.view)
        timerVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            timerVC.view.centerXAnchor.constraint(equalTo: dimView.centerXAnchor),
            timerVC.view.centerYAnchor.constraint(equalTo: dimView.centerYAnchor),
            timerVC.view.widthAnchor.constraint(equalToConstant: 260),
            timerVC.view.heightAnchor.constraint(equalToConstant: 280),
        ])

        view.addSubview(dimView)
    }
}

private class DismissableDimView: UIView {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?() }
}

// MARK: - SwiftUI Wrapper

struct DialogsUIKitViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DialogsUIKitViewController {
        DialogsUIKitViewController()
    }

    func updateUIViewController(_ uiViewController: DialogsUIKitViewController, context: Context) { }
}

struct DialogsUIKitView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            DialogsUIKitViewControllerWrapper()
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Dialogs (UIKit)")
                .toolbar {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
        }
    }
}
#endif
