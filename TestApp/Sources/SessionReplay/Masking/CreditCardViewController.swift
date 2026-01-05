import UIKit

// MARK: - Model
#if os(iOS)

public struct CreditCard: Equatable {
    public var cardholder: String
    public var number: String          // PAN digits only (no spaces)
    public var brand: CardBrand
    public var expiryMonth: Int
    public var expiryYear2D: Int       // YY (e.g., 29 for 2029)
    public var cvv: String
    public var postalCode: String?
}

public enum CardBrand: String {
    case visa = "Visa"
    case masterCard = "Mastercard"
    case amex = "American Express"
    case unknown = "Unknown"
    
    var cvvLength: Int { self == .amex ? 4 : 3 }
    var panMaxLength: Int { self == .amex ? 15 : 16 }
    var formattedGrouping: [Int] {
        switch self {
        case .amex: return [4, 6, 5]
        default:    return [4, 4, 4, 4]
        }
    }
    
    static func detect(from digits: String) -> CardBrand {
        // Quick-n-dirty BIN rules for demo purposes
        if digits.hasPrefix("4") { return .visa }
        // Mastercard: 51-55, 2221-2720
        if let prefix2 = Int(digits.prefix(2)), (51...55).contains(prefix2) { return .masterCard }
        if let prefix4 = Int(digits.prefix(4)), (2221...2720).contains(prefix4) { return .masterCard }
        // AmEx: 34, 37
        if digits.hasPrefix("34") || digits.hasPrefix("37") { return .amex }
        return .unknown
    }
}

// MARK: - Delegate

public protocol CreditCardViewControllerDelegate: AnyObject {
    func creditCardViewController(_ vc: CreditCardViewController, didSave card: CreditCard)
    func creditCardViewControllerDidCancel(_ vc: CreditCardViewController)
}

// MARK: - Controller

public final class CreditCardViewController: UIViewController {
    var testAnimation: TestAnimation? {
        didSet {
            guard isViewLoaded, oldValue != testAnimation else { return }
            
            if oldValue == .rotate {
                stack.layer.removeAllAnimations()
                cvvContainer?.layer.removeAllAnimations()
            }
            
            switch testAnimation  {
            case .slideInFromBottom:
                cover.backgroundColor = .blue
                startSlidingFromBottom(view: cover)
            case .slideInFromRight:
                cover.backgroundColor = .blue
                startSlidingFromRight(view: cover)
            case .rotate:
               cover.backgroundColor = .clear
               startRotating(view: stack)
               if let cvvContainer = cvvContainer {
                   startRotating(view: cvvContainer, duration: 1.0)
               }
            case .none:
                cover.backgroundColor = .clear
            }
        }
    }
    public weak var delegate: CreditCardViewControllerDelegate?
    
    // MARK: UI
    private let scroll = UIScrollView()
    private let stack  = UIStackView()
    
    private let nameField   = UITextField()
    private let numberField = UITextField()
    private let brandChip   = UILabel()
    private let expiryField = UITextField()
    private let cvvField    = UITextField()
    private var cvvContainer: UIStackView?
    private let postalField = UITextField()
    private let saveButton  = UIButton(type: .system)
    private let cover = UIView()
    
    // Accessory toolbar
    private lazy var kbToolbar: UIToolbar = {
        let tb = UIToolbar()
        tb.sizeToFit()
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))
        tb.items = [flex, done]
        return tb
    }()
    
    // Internal state
    private var currentBrand: CardBrand = .unknown {
        didSet { updateBrandChip() }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNav()
        setupLayout()
        updateSaveButton()
        
        nameField.ldUnmask()
        brandChip.accessibilityIdentifier = "card-brand-chip"
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        cover.frame = view.bounds
        //startSliding(view: cover)
    }
    
    // MARK: - Public prefill (optional)
    public func prefill(card: CreditCard) {
        nameField.text = card.cardholder
        currentBrand = card.brand
        numberField.text = Self.formatPAN(card.number, brand: currentBrand)
        expiryField.text = String(format: "%02d/%02d", card.expiryMonth, card.expiryYear2D)
        cvvField.text = String(card.cvv.prefix(currentBrand.cvvLength))
        postalField.text = card.postalCode
        updateSaveButton()
    }
    
    // MARK: UI Setup
    
    private func setupNav() {
       // navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(cancelTapped))
    }
    
    private func setupLayout() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        stack.axis = .vertical
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        scroll.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor)
        ])
        
        addLabeledField(title: "Name on Card", field: nameField)
        
        // Card number row with brand chip
        let numberRow = UIStackView()
        numberRow.axis = .horizontal
        numberRow.spacing = 8
        
        let numberContainer = fieldContainer(title: "Card Number")
        numberField.placeholder = "1234 5678 9012 3456"
        numberField.keyboardType = .numberPad
        numberField.inputAccessoryView = kbToolbar
        numberField.delegate = self
        numberContainer.addArrangedSubview(numberField)
        
        brandChip.text = "Unknown"
        brandChip.font = UIFont.preferredFont(forTextStyle: .footnote)
        brandChip.textColor = .secondaryLabel
        brandChip.textAlignment = .center
        brandChip.backgroundColor = UIColor.secondarySystemBackground
        brandChip.layer.cornerRadius = 8
        brandChip.clipsToBounds = true
        brandChip.setContentHuggingPriority(.required, for: .horizontal)
        brandChip.widthAnchor.constraint(equalToConstant: 90).isActive = true
        brandChip.heightAnchor.constraint(equalToConstant: 64).isActive = true
        
        numberRow.addArrangedSubview(numberContainer)
        numberRow.addArrangedSubview(brandChip)
        stack.addArrangedSubview(numberRow)
        
        // Expiry + CVV row
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        
        let expiryContainer = fieldContainer(title: "Expiry (MM/YY)")
        expiryField.placeholder = "MM/YY"
        expiryField.keyboardType = .numberPad
        expiryField.inputAccessoryView = kbToolbar
        expiryField.delegate = self
        expiryContainer.addArrangedSubview(expiryField)
        
        let cvvContainer = self.cvvContainer ?? fieldContainer(title: "CVV")
        cvvField.placeholder = "123"
        cvvField.isSecureTextEntry = true
        cvvField.keyboardType = .numberPad
        cvvField.inputAccessoryView = kbToolbar
        cvvField.delegate = self
        cvvContainer.addArrangedSubview(cvvField)
        self.cvvContainer = cvvContainer
        cvvContainer.ldPrivate()
        
        row.addArrangedSubview(expiryContainer)
        row.addArrangedSubview(cvvContainer)
        stack.addArrangedSubview(row)
        
        // Postal
        addLabeledField(title: "ZIP / Postal", field: postalField)
        postalField.placeholder = "Optional"
        postalField.keyboardType = .default
        postalField.autocapitalizationType = .allCharacters
        postalField.inputAccessoryView = kbToolbar
        postalField.delegate = self
        postalField.ldPrivate(isEnabled: false)
        
        // Save button
        saveButton.setTitle("Save Card", for: .normal)
        saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        saveButton.isEnabled = false
        saveButton.backgroundColor = .systemBlue
        saveButton.tintColor = .white
        saveButton.layer.cornerRadius = 12
        saveButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        stack.addArrangedSubview(saveButton)
        
        
        cover.backgroundColor = .clear
      //  cover.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cover)
//        NSLayoutConstraint.activate([
//            cover.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            cover.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            cover.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
//            cover.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
    }
    
    private func addLabeledField(title: String, field: UITextField) {
        let container = fieldContainer(title: title)
        field.inputAccessoryView = kbToolbar
        field.autocapitalizationType = .words
        field.clearButtonMode = .whileEditing
        field.delegate = self
        container.addArrangedSubview(field)
        stack.addArrangedSubview(container)
    }
    
    private func fieldContainer(title: String) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        
        let v = UIStackView(arrangedSubviews: [titleLabel])
        v.axis = .vertical
        v.spacing = 6
        v.isLayoutMarginsRelativeArrangement = true
        v.layoutMargins = .zero
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 12
        v.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return v
    }
    
    // MARK: - Actions
    
    @objc private func doneTapped() {
        view.endEditing(true)
    }
    
    @objc private func cancelTapped() {
        delegate?.creditCardViewControllerDidCancel(self)
    }
    
    @objc private func saveTapped() {
        guard let card = buildCardIfValid() else { return }
        delegate?.creditCardViewController(self, didSave: card)
    }
    
    // MARK: - Validation
    
    private func updateBrandChip() {
        brandChip.text = currentBrand.rawValue
        brandChip.textColor = currentBrand == .unknown ? .secondaryLabel : .label
    }
    
    private func updateSaveButton() {
        saveButton.isEnabled = buildCardIfValid() != nil
        saveButton.alpha = saveButton.isEnabled ? 1.0 : 0.5
    }
    
    private func buildCardIfValid() -> CreditCard? {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let numberDigits = Self.digitsOnly(numberField.text ?? "")
        let brand = CardBrand.detect(from: numberDigits)
        
        // PAN length + Luhn
        guard numberDigits.count == brand.panMaxLength || (brand == .unknown && (13...19).contains(numberDigits.count)) else { return nil }
        guard Self.luhnIsValid(numberDigits) else { return nil }
        
        // Expiry
        guard let (mm, yy) = Self.parseExpiry(expiryField.text ?? "") else { return nil }
        guard Self.expiryIsFuture(month: mm, year2D: yy) else { return nil }
        
        // CVV
        let cvvDigits = Self.digitsOnly(cvvField.text ?? "")
        let cvvLen = (brand == .unknown) ? (3...4).contains(cvvDigits.count) : cvvDigits.count == brand.cvvLength
        guard cvvLen else { return nil }
        
        // Name non-empty
        guard !name.isEmpty else { return nil }
        
        // Postal optional (allow 3-10 alnum)
        var postal = (postalField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if postal.isEmpty { postal = "" }
        else if !Self.isAlnumLen(postal, min: 3, max: 10) { return nil }
        
        return CreditCard(
            cardholder: name,
            number: numberDigits,
            brand: brand,
            expiryMonth: mm,
            expiryYear2D: yy,
            cvv: cvvDigits,
            postalCode: postal.isEmpty ? nil : postal.uppercased()
        )
    }
}

// MARK: - UITextFieldDelegate

extension CreditCardViewController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Provide formatting behaviors
        if textField == numberField {
            let current = textField.text ?? ""
            guard let textRange = Range(range, in: current) else { return false }
            let replaced = current.replacingCharacters(in: textRange, with: string)
            let digits = Self.digitsOnly(replaced)
            
            // Detect brand from digits and cap length accordingly
            let brand = CardBrand.detect(from: digits)
            currentBrand = brand
            let capped = String(digits.prefix(brand.panMaxLength))
            textField.text = Self.formatPAN(capped, brand: brand)
            updateSaveButton()
            return false
        }
        if textField == expiryField {
            let current = textField.text ?? ""
            guard let textRange = Range(range, in: current) else { return false }
            var raw = current.replacingCharacters(in: textRange, with: string)
            raw = Self.digitsOnly(raw)
            if raw.count > 4 { raw = String(raw.prefix(4)) }
            var formatted = ""
            if raw.count >= 3 {
                let mm = String(raw.prefix(2))
                let yy = String(raw.suffix(from: raw.index(raw.startIndex, offsetBy: 2)))
                formatted = "\(mm)/\(yy)"
            } else if raw.count >= 1 {
                if raw.count == 1 {
                    // auto-prefix '0' for months 2..9? Keep simple; allow 1..12 typed
                    formatted = raw
                } else {
                    let mm = String(raw.prefix(2))
                    formatted = mm + "/"
                }
            }
            textField.text = formatted
            updateSaveButton()
            return false
        }
        if textField == cvvField {
            let brand = currentBrand
            let current = textField.text ?? ""
            guard let r = Range(range, in: current) else { return false }
            var new = current.replacingCharacters(in: r, with: string)
            new = String(Self.digitsOnly(new).prefix(brand == .unknown ? 4 : brand.cvvLength))
            textField.text = new
            updateSaveButton()
            return false
        }
        if textField == postalField {
            // Uppercase, cap length to 10, alnum only
            let current = textField.text ?? ""
            guard let r = Range(range, in: current) else { return false }
            var new = current.replacingCharacters(in: r, with: string.uppercased())
            new = new.uppercased()
            new = new.filter { $0.isNumber || ($0 >= "A" && $0 <= "Z") }
            if new.count > 10 { new = String(new.prefix(10)) }
            textField.text = new
            updateSaveButton()
            return false
        }
        // Default: allow change & update save state
        DispatchQueue.main.async { [weak self] in self?.updateSaveButton() }
        return true
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        updateSaveButton()
    }
}

// MARK: - Helpers

private extension CreditCardViewController {
    static func digitsOnly(_ s: String) -> String { s.filter(\.isNumber) }
    
    static func formatPAN(_ digits: String, brand: CardBrand) -> String {
        let groups = brand.formattedGrouping
        var result: [String] = []
        var idx = digits.startIndex
        for size in groups where idx < digits.endIndex {
            let nextIdx = digits.index(idx, offsetBy: size, limitedBy: digits.endIndex) ?? digits.endIndex
            result.append(String(digits[idx..<nextIdx]))
            idx = nextIdx
        }
        if idx < digits.endIndex { result.append(String(digits[idx...])) }
        return result.filter { !$0.isEmpty }.joined(separator: " ")
    }
    
    static func luhnIsValid(_ digits: String) -> Bool {
        var sum = 0
        let reversed = digits.reversed().map { Int(String($0)) ?? 0 }
        for (i, d) in reversed.enumerated() {
            if i % 2 == 1 {
                let doubled = d * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }
    
    static func parseExpiry(_ text: String) -> (Int, Int)? {
        let raw = digitsOnly(text)
        guard raw.count == 4 else { return nil }
        let mm = Int(raw.prefix(2)) ?? 0
        let yy = Int(raw.suffix(2)) ?? 0
        guard (1...12).contains(mm) else { return nil }
        return (mm, yy)
    }
    
    static func expiryIsFuture(month: Int, year2D: Int) -> Bool {
        // Compare to current calendar month (uses device locale/timezone)
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let curY = comps.year, let curM = comps.month else { return false }
        let curYY = curY % 100
        if year2D > curYY { return true }
        if year2D < curYY { return false }
        return month >= curM
    }
    
    static func isAlnumLen(_ text: String, min: Int, max: Int) -> Bool {
        guard (min...max).contains(text.count) else { return false }
        return text.allSatisfy { $0.isNumber || ($0 >= "A" && $0 <= "Z") || ($0 >= "a" && $0 <= "z") }
    }
}

// MARK: - Usage (example)
/*
 let vc = CreditCardViewController()
 vc.delegate = self
 let nav = UINavigationController(rootViewController: vc)
 present(nav, animated: true)
 
 extension YourController: CreditCardViewControllerDelegate {
     func creditCardViewController(_ vc: CreditCardViewController, didSave card: CreditCard) {
         // Use the sanitized card model (PAN digits only, uppercased postal)
         print("Saved card: \(card)")
         vc.dismiss(animated: true)
     }
     func creditCardViewControllerDidCancel(_ vc: CreditCardViewController) {
         vc.dismiss(animated: true)
     }
 }
*/

import SwiftUI

enum TestAnimation {
    case slideInFromBottom
    case slideInFromRight
    case rotate
}

// MARK: - Wrapper for UIKit controller
struct CreditCardControllerWrapper: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var testAnimation: TestAnimation
    
    func makeUIViewController(context: Context) -> CreditCardViewController {
        //let ccVC = CreditCardViewController()
        //ccVC.delegate = context.coordinator
        return CreditCardViewController()
    }
    
    func updateUIViewController(_ uiViewController: CreditCardViewController, context: Context) {
        uiViewController.testAnimation = testAnimation
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CreditCardViewControllerDelegate {
        let parent: CreditCardControllerWrapper
        init(_ parent: CreditCardControllerWrapper) { self.parent = parent }
        
        func creditCardViewController(_ vc: CreditCardViewController, didSave card: CreditCard) {
            print("✅ Got card: \(card)")
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func creditCardViewControllerDidCancel(_ vc: CreditCardViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct MaskingCreditCardUIKitView: View {
    @Environment(\.dismiss) var dismiss
    @State var testAnimation: TestAnimation = .rotate
    
    var body: some View {
        NavigationStack {
            CreditCardControllerWrapper(testAnimation: testAnimation)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Masking Elements (UIKit)")
                .toolbar {
                    Button {
                        testAnimation = (testAnimation == .rotate) ? .slideInFromBottom : .rotate
                    } label: {
                        Image(systemName: "arrow.down")
                    }
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

#endif
