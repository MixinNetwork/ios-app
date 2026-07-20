import UIKit
import MixinServices

struct MnemonicsInputField {
    
    enum BackgroundColor {
        case primary
        case secondary
    }
    
    enum TextColor {
        case normal
        case invalid
    }
    
    let label: UILabel
    let textField: MnemonicTextField
    
    func setTextColor(_ color: TextColor) {
        switch color {
        case .normal:
            label.textColor = R.color.text_tertiary()
            textField.textColor = R.color.text()
        case .invalid:
            label.textColor = R.color.error_red()
            textField.textColor = R.color.error_red()
        }
    }
    
    func setTextColor(phrase: String?) {
        if let phrase, !phrase.isEmpty {
            if BIP39.wordlist.contains(phrase) {
                setTextColor(.normal)
            } else {
                setTextColor(.invalid)
            }
        } else {
            setTextColor(.normal)
        }
    }
    
}
