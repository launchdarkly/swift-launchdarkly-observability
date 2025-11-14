#if os(iOS)

import SwiftUI
import LaunchDarklySessionReplay

struct MaskingCreditCardSwiftUIView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Inputs
    @State private var nameOnCard: String = ""
    @State private var cardNumber: String = ""
    @State private var expiry: String = ""
    @State private var cvv: String = ""
    @State private var postal: String = ""
    
    // Derived state
    @State private var currentBrand: CardBrand = .unknown
    
    private var isFormValid: Bool {
        let numberDigits = Self.digitsOnly(cardNumber)
        let brand = CardBrand.detect(from: numberDigits)
        
        let panLengthOK: Bool = {
            if brand == .unknown {
                return (13...19).contains(numberDigits.count)
            }
            return numberDigits.count == brand.panMaxLength
        }()
        guard panLengthOK, Self.luhnIsValid(numberDigits) else { return false }
        
        guard let (mm, yy) = Self.parseExpiry(expiry), Self.expiryIsFuture(month: mm, year2D: yy) else { return false }
        
        let cvvDigits = Self.digitsOnly(cvv)
        let cvvLenOK = (brand == .unknown) ? (3...4).contains(cvvDigits.count) : cvvDigits.count == brand.cvvLength
        guard cvvLenOK else { return false }
        
        guard !nameOnCard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        
        if postal.isEmpty { return true }
        return Self.isAlnumLen(postal, min: 3, max: 10)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    labeledField(title: "Name on Card") {
                        TextField("Full name", text: $nameOnCard)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .ldUnmask()
                    }
                    
                    // Card number + brand chip
                    HStack(alignment: .top, spacing: 8) {
                        labeledField(title: "Card Number") {
                            if #available(iOS 17.0, *) {
                                TextField("1234 5678 9012 3456", text: $cardNumber)
                                    .keyboardType(.numberPad)
                                    .onChange(of: cardNumber) { _, new in
                                        let digits = Self.digitsOnly(new)
                                        let brand = CardBrand.detect(from: digits)
                                        currentBrand = brand
                                        let capped = String(digits.prefix(brand.panMaxLength))
                                        let formatted = Self.formatPAN(capped, brand: brand)
                                        if formatted != cardNumber {
                                            cardNumber = formatted
                                        }
                                    }
                            } else {
                                TextField("1234 5678 9012 3456", text: $cardNumber)
                                    .keyboardType(.numberPad)
                            }
                        }
                        brandChip(currentBrand)
                    }
                    
                    // Expiry + CVV
                    HStack(spacing: 12) {
                        labeledField(title: "Expiry (MM/YY)") {
                            if #available(iOS 17.0, *) {
                                TextField("MM/YY", text: $expiry)
                                    .keyboardType(.numberPad)
                                    .onChange(of: expiry) { _, new in
                                        var raw = Self.digitsOnly(new)
                                        if raw.count > 4 { raw = String(raw.prefix(4)) }
                                        var formatted = ""
                                        if raw.count >= 3 {
                                            let mm = String(raw.prefix(2))
                                            let yy = String(raw.suffix(raw.count - 2))
                                            formatted = "\(mm)/\(yy)"
                                        } else if raw.count >= 1 {
                                            if raw.count == 1 {
                                                formatted = raw
                                            } else {
                                                let mm = String(raw.prefix(2))
                                                formatted = mm + "/"
                                            }
                                        }
                                        if formatted != expiry {
                                            expiry = formatted
                                        }
                                    }
                            } else {
                                TextField("MM/YY", text: $expiry)
                                    .keyboardType(.numberPad)
                            }
                        }
                        
                        labeledField(title: "CVV") {
                                SecureField(currentBrand == .amex ? "1234" : "123", text: $cvv)
                                    .keyboardType(.numberPad)
                                    .ldPrivate()
                        }
                    }
                    
                    labeledField(title: "ZIP / Postal") {
                        TextField("Optional", text: $postal)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .ldPrivate(isEnabled: false)
                    }
                    
                    Button {
                        save()
                    } label: {
                        Text("Save Card")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Masking Elements (SwiftUI)")
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
    
    private func labeledField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack {
                content()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private func brandChip(_ brand: CardBrand) -> some View {
        Text(brand.rawValue)
            .font(.footnote)
            .foregroundColor(brand == .unknown ? .secondary : .primary)
            .frame(minWidth: 90, minHeight: 64)
            .padding(.horizontal, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            .accessibilityIdentifier("card-brand-chip")
    }
    
    private func save() {
        guard let (mm, yy) = Self.parseExpiry(expiry) else { return }
        let numberDigits = Self.digitsOnly(cardNumber)
        let cvvDigits = Self.digitsOnly(cvv)
        let card = CreditCard(
            cardholder: nameOnCard.trimmingCharacters(in: .whitespacesAndNewlines),
            number: numberDigits,
            brand: CardBrand.detect(from: numberDigits),
            expiryMonth: mm,
            expiryYear2D: yy,
            cvv: cvvDigits,
            postalCode: postal.isEmpty ? nil : postal
        )
        print("✅ Saved card (SwiftUI): \(card)")
        dismiss()
    }
}

// MARK: - Helpers
private extension MaskingCreditCardSwiftUIView {
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

#Preview {
    MaskingCreditCardSwiftUIView()
}

#endif


