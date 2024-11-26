import UIKit
import MixinServices

class InputMnemonicsViewController: MnemonicsViewController {
    
    private let mnemonicsInputAccessoryView = R.nib.mnemonicsInputAccessoryView(withOwner: nil)!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mnemonicsInputAccessoryView.delegate = self
    }
    
    private func showInputAccessoryView(textField: UITextField) {
        guard textField.inputAccessoryView == nil else {
            return
        }
        mnemonicsInputAccessoryView.textField = textField
        textField.inputAccessoryView = mnemonicsInputAccessoryView
        textField.reloadInputViews()
    }
    
    private func hideInputAccessoryView(textField: UITextField) {
        guard textField.inputAccessoryView != nil else {
            return
        }
        mnemonicsInputAccessoryView.textField = nil
        textField.inputAccessoryView = nil
        textField.reloadInputViews()
    }
    
    private func reloadInputAccessoryView(textField: UITextField, keyword: String?) {
        let words: [String]
        if let keyword, !keyword.isEmpty {
            words = BIP39.wordlist.filter { word in
                word.hasPrefix(keyword)
            }
        } else {
            words = []
        }
        if words.isEmpty {
            hideInputAccessoryView(textField: textField)
        } else {
            showInputAccessoryView(textField: textField)
            mnemonicsInputAccessoryView.reloadData(words: words)
        }
    }
    
    private func handleInputFinished(textField: UITextField) {
        let nextIndex = textField.tag + 1
        if nextIndex == textFields.count {
            textField.resignFirstResponder()
        } else {
            textFields[nextIndex].becomeFirstResponder()
        }
    }
    
}

extension InputMnemonicsViewController: UITextFieldDelegate {
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        reloadInputAccessoryView(textField: textField, keyword: textField.text)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        hideInputAccessoryView(textField: textField)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let text = (textField.text ?? "") as NSString
        let newText = text.replacingCharacters(in: range, with: string)
        reloadInputAccessoryView(textField: textField, keyword: newText)
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        handleInputFinished(textField: textField)
        return false
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        hideInputAccessoryView(textField: textField)
        return true
    }
    
}

extension InputMnemonicsViewController: MnemonicsInputAccessoryView.Delegate {
    
    func mnemonicsInputAccessoryView(_ view: MnemonicsInputAccessoryView, didSelect word: String) {
        guard let textField = view.textField else {
            return
        }
        textField.text = word
        handleInputFinished(textField: textField)
    }
    
}
