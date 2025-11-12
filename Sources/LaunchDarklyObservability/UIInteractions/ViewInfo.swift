import UIKit

public struct ViewInfo {
    public let title: String?
    public let category: String
    
    init(title: String?, category: String) {
        self.title = title.map { String($0.prefix(200)) }
        self.category = category
    }
}

// MARK: - Public entry point that accepts either UIView or UIBarButtonItem
public func extractTitleAndCategory(from object: Any?) -> ViewInfo {
    switch object {
    case let view as UIView:
        return view.extractViewInfo()
    case let item as UIBarButtonItem:
        return item.extractViewInfo()
    default:
        return ViewInfo(title: nil, category: String(describing: type(of: object as Any)))
    }
}

// MARK: - UIView extraction (covers _UIButtonBarButton too)
extension UIView {
    public func extractViewInfo() -> ViewInfo {
        // 1) Known UIKit controls
        if let button = self as? UIButton {
            let title = firstNonEmpty(
                button.titleLabel?.text,
                button.currentTitle,
                button.title(for: .normal),
                button.attributedTitle(for: .normal)?.string,
                self.accessibilityLabel
            )
            return ViewInfo(title: title, category: "button")
        }
        if let label = self as? UILabel {
            return ViewInfo(title: firstNonEmpty(label.text, self.accessibilityLabel), category: "label")
        }
        if let tf = self as? UITextField {
            return ViewInfo(title: firstNonEmpty(tf.text, tf.placeholder, self.accessibilityLabel), category: "textField")
        }
        if let tv = self as? UITextView {
            return ViewInfo(title: firstNonEmpty(tv.text, self.accessibilityLabel), category: "textView")
        }
        if let sb = self as? UISearchBar {
            return ViewInfo(title: firstNonEmpty(sb.text, sb.placeholder, self.accessibilityLabel), category: "searchBar")
        }
        if let seg = self as? UISegmentedControl {
            let selected = seg.selectedSegmentIndex
            let selectedTitle = selected >= 0 ? seg.titleForSegment(at: selected) : nil
            let title = firstNonEmpty(selectedTitle, allSegmentTitles(seg), self.accessibilityLabel)
            return ViewInfo(title: title, category: "segmentedControl")
        }

        // 2) Private bar button view (_UIButtonBarButton / UIButtonBarButton)
        let className = String(describing: type(of: self))
        if className.contains("UIButtonBarButton") {
            // These almost always carry the UIBarButtonItem’s label as accessibilityLabel.
            let title = firstNonEmpty(self.accessibilityLabel, firstDescendantTitle())
            return ViewInfo(title: title, category: "button")
        }

        // 3) Generic fallback: try accessibility first, then scan descendants
        if let title = firstNonEmpty(self.accessibilityLabel, firstDescendantTitle()) {
            return ViewInfo(title: title, category: String(describing: type(of: self)))
        }
        return ViewInfo(title: nil, category: String(describing: type(of: self)))
    }

    // Depth-first search for a sensible text inside subviews (UILabel/UIButton)
    private func firstDescendantTitle() -> String? {
        if let label = self as? UILabel, let t = cleaned(label.text) { return t }
        if let btn = self as? UIButton {
            return firstNonEmpty(btn.titleLabel?.text, btn.currentTitle, btn.title(for: .normal), btn.attributedTitle(for: .normal)?.string)
        }
        for sub in subviews {
            if let t = sub.firstDescendantTitle() { return t }
        }
        return nil
    }

    private func allSegmentTitles(_ seg: UISegmentedControl) -> String? {
        guard seg.numberOfSegments > 0 else { return nil }
        let titles = (0..<seg.numberOfSegments)
            .compactMap { seg.titleForSegment(at: $0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return titles.isEmpty ? nil : titles.joined(separator: ", ")
    }
}

// MARK: - UIBarButtonItem extraction
extension UIBarButtonItem {
    public func extractViewInfo() -> ViewInfo {
        // Prefer explicit title / a11y label if available.
        if let t = firstNonEmpty(self.title, self.accessibilityLabel) {
            return ViewInfo(title: t, category: "button")
        }
        // If there is a customView, inspect it like any other UIView.
        if let v = self.customView {
            let info = v.extractViewInfo()
            // Coerce category to "button" since this is a bar button.
            return ViewInfo(title: info.title, category: "button")
        }
        // Nothing obvious available.
        return ViewInfo(title: nil, category: "button")
    }
}

// MARK: - Small helpers
@inline(__always)
private func cleaned(_ s: String?) -> String? {
    guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    return s
}

@inline(__always)
private func firstNonEmpty(_ candidates: String?...) -> String? {
    for c in candidates {
        if let v = cleaned(c) { return v }
    }
    return nil
}
