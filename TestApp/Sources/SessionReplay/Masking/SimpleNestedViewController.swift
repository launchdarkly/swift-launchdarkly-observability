import UIKit

public final class SimpleNestedViewController: UIViewController {
    public weak var delegate: SimpleNestedViewControllerDelegate?
    
    private lazy var cvvField: UITextField = {
        let field = UITextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .systemFont(ofSize: 30)
        field.text = "123"
        field.accessibilityIdentifier = "cvvField"
        field.backgroundColor = .yellow
        return field
    }()
    
    private lazy var cvvContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.accessibilityIdentifier = "cvvContainer"
        view.backgroundColor = .tintColor
        return view
    }()
    
    private let cover = UIView()
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        #if os(iOS)
        view.backgroundColor = .systemBackground
        #endif
        view.accessibilityIdentifier = "nestedViewController"

        view.addSubview(cvvContainer)
        NSLayoutConstraint.activate([
            cvvContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cvvContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cvvContainer.widthAnchor.constraint(equalToConstant: 100),
            cvvContainer.heightAnchor.constraint(equalToConstant: 100),
        ])
        
        
        cvvContainer.addSubview(cvvField)
        NSLayoutConstraint.activate([
            cvvField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cvvField.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        //startRotating(view: cvvField)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        cover.backgroundColor = .blue
        cover.frame = view.bounds
        cover.accessibilityIdentifier = "cover"

        view.addSubview(cover)
        
        startSlidingFromRight(view: cover)
    }
}

public protocol SimpleNestedViewControllerDelegate: AnyObject {
//    func creditCardViewController(_ vc: CreditCardViewController, didSave card: CreditCard)
//    func creditCardViewControllerDidCancel(_ vc: CreditCardViewController)
}

import SwiftUI

// MARK: - Wrapper for UIKit controller
struct SimpleNestedViewControllerWrapper: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIViewController {
        //let ccVC = CreditCardViewController()
        //ccVC.delegate = context.coordinator
        return SimpleNestedViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SimpleNestedViewControllerDelegate {
        let parent: SimpleNestedViewControllerWrapper
        init(_ parent: SimpleNestedViewControllerWrapper) { self.parent = parent }
        
//        func creditCardViewController(_ vc: SimpleNestedViewController, didSave card: CreditCard) {
//            parent.presentationMode.wrappedValue.dismiss()
//        }
//        
//        func creditCardViewControllerDidCancel(_ vc: SimpleNestedViewController) {
//            parent.presentationMode.wrappedValue.dismiss()
//        }
    }
}

struct MaskingElementsSimpleUIKitView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            SimpleNestedViewControllerWrapper()
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .navigationTitle("Masking Simple View (UIKit)")
                .toolbar {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }.ldMask()
                    SnapshotButton()
                }
        }
    }
}

