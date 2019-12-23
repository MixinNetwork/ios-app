import UIKit

extension UIButton {

    @IBInspectable
    var local_title: String? {
        get {
            return ""
        }
        set {
            guard let text = newValue, !text.isEmpty else {
                return
            }
            let localText = LocalizedString(text, comment: text)
            if localText != text {
                self.setTitle(localText, for: .normal)
            }
        }
    }
}

extension UILabel {
    
    @IBInspectable
    var local_title: String? {
        get {
            return ""
        }
        set {
            guard let text = newValue, !text.isEmpty else {
                return
            }
            let localText = LocalizedString(text, comment: text)
            if localText != text {
                self.text = localText
            }
        }
    }
}

extension UITextField {
    
    @IBInspectable
    var local_placeholder: String? {
        get {
            return ""
        }
        set {
            guard let text = newValue, !text.isEmpty else {
                return
            }
            let localText = LocalizedString(text, comment: text)
            if localText != text {
                self.placeholder = localText
            }
        }
    }
    
}

extension UINavigationItem {
    
    @IBInspectable
    var local_title: String? {
        get {
            return ""
        }
        set {
            guard let text = newValue, !text.isEmpty else {
                return
            }
            let localText = LocalizedString(text, comment: text)
            if localText != text {
                self.title = localText
            }
        }
    }
    
}

extension SearchBoxView {

    @IBInspectable
    var local_placeholder: String? {
        get {
            return ""
        }
        set {
            guard let text = newValue, !text.isEmpty else {
                return
            }
            let localText = LocalizedString(text, comment: text)
            if localText != text {
                self.textField.placeholder = localText
            }
        }
    }
}
