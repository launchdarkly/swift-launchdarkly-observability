import UIKit
import SwiftUI
import LaunchDarklySessionReplay

public final class NestedMaskingPropagationUIKitViewController: UIViewController {

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        // 1. Baseline — no marker. Globally masked by maskTextInputs.
        stack.addArrangedSubview(makeSection(
            title: "1. Baseline (no marker)",
            note: "Globally masked by maskTextInputs.",
            tint: .clear,
            placeholder: "type here"
        ).wrapper)

        // 2. Ancestor .ldUnmask() — child should be visible.
        let s2 = makeSection(
            title: "2. Ancestor .ldUnmask()",
            note: "Container has .ldUnmask() — child UITextField should be visible.",
            tint: UIColor.systemGreen.withAlphaComponent(0.15),
            placeholder: "visible inside unmasked ancestor"
        )
        s2.content.ldUnmask()
        stack.addArrangedSubview(s2.wrapper)

        // 3. Ancestor .ldMask() — content container including children gets masked.
        let s3 = makeSection(
            title: "3. Ancestor .ldMask()",
            note: "Container has .ldMask() — both label and field get covered.",
            tint: UIColor.systemRed.withAlphaComponent(0.15),
            placeholder: "field inside masked ancestor",
            extraLabel: "plain label that would normally be visible"
        )
        s3.content.ldMask()
        stack.addArrangedSubview(s3.wrapper)

        // 4. Deep nesting under .ldUnmask() — propagation across two levels.
        let s4 = makeSection(
            title: "4. Deep unmask through nesting",
            note: "Two levels of nesting under .ldUnmask() — should still be visible.",
            tint: UIColor.systemGreen.withAlphaComponent(0.05),
            placeholder: "deeply nested, still unmasked"
        )
        let outerUnmask = UIView()
        outerUnmask.translatesAutoresizingMaskIntoConstraints = false
        outerUnmask.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
        outerUnmask.layer.cornerRadius = 8
        outerUnmask.addSubview(s4.content)
        NSLayoutConstraint.activate([
            s4.content.topAnchor.constraint(equalTo: outerUnmask.topAnchor, constant: 8),
            s4.content.bottomAnchor.constraint(equalTo: outerUnmask.bottomAnchor, constant: -8),
            s4.content.leadingAnchor.constraint(equalTo: outerUnmask.leadingAnchor, constant: 8),
            s4.content.trailingAnchor.constraint(equalTo: outerUnmask.trailingAnchor, constant: -8),
        ])
        outerUnmask.ldUnmask()
        let s4Stack = UIStackView(arrangedSubviews: [s4.titleLabel, s4.noteLabel, outerUnmask])
        s4Stack.axis = .vertical
        s4Stack.spacing = 6
        stack.addArrangedSubview(s4Stack)
    }

    private struct Section {
        let wrapper: UIView
        let content: UIView
        let titleLabel: UILabel
        let noteLabel: UILabel
    }

    private func makeSection(title: String,
                             note: String,
                             tint: UIColor,
                             placeholder: String,
                             extraLabel: String? = nil) -> Section {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 0

        let noteLabel = UILabel()
        noteLabel.text = note
        noteLabel.font = .preferredFont(forTextStyle: .caption1)
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 0

        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = placeholder
        textField.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        if let extraLabel {
            let extra = UILabel()
            extra.text = extraLabel
            extra.font = .preferredFont(forTextStyle: .body)
            extra.numberOfLines = 0
            contentStack.addArrangedSubview(extra)
        }
        contentStack.addArrangedSubview(textField)

        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.backgroundColor = tint
        content.layer.cornerRadius = 8
        content.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            contentStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
            contentStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            contentStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
        ])

        let wrapper = UIStackView(arrangedSubviews: [titleLabel, noteLabel, content])
        wrapper.axis = .vertical
        wrapper.spacing = 6
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        return Section(wrapper: wrapper, content: content, titleLabel: titleLabel, noteLabel: noteLabel)
    }
}

struct NestedMaskingPropagationUIKitView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            UIKitWrapper()
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .navigationTitle("Ancestor Propagation (UIKit)")
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

    private struct UIKitWrapper: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> UIViewController {
            NestedMaskingPropagationUIKitViewController()
        }
        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    }
}
