import UIKit
import MixinServices

final class CheckMnemonicsViewController: InputMnemonicsViewController {
    
    private enum CheckingError: Error {
        case mismatched
    }
    
    private let mnemonics: MixinMnemonics
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    init(mnemonics: MixinMnemonics) {
        self.mnemonics = mnemonics
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.check_mnemonic_phrase()
        descriptionLabel.text = R.string.localizable.check_mnemonic_phrase_desc()
        addTextFields(count: mnemonics.phrases.count)
        for textField in inputFields.map(\.textField) {
            if textField.tag == mnemonics.phrases.count - 1 {
                textField.returnKeyType = .done
            } else {
                textField.returnKeyType = .next
            }
            textField.clearButtonMode = .whileEditing
            textField.delegate = self
            textField.deleteDelegate = self
        }
        addSpacerIntoInputFields()
        addButtonIntoInputFields(
            image: R.image.explore.web3_send_delete()!,
            title: R.string.localizable.clear(),
            action: #selector(emptyPhrases(_:))
        )
        confirmButton.setTitle(R.string.localizable.complete(), for: .normal)
        confirmButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .semibold), adjustForContentSize: true)
        confirmButton.isEnabled = false
        NotificationCenter.default.addObserver(self, selector: #selector(detectPhrases(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func confirm(_ sender: Any) {
        do {
            let inputMnemonics = try MixinMnemonics(phrases: textFieldPhrases)
            if inputMnemonics == mnemonics {
                let alert = UIAlertController(
                    title: R.string.localizable.backup_mnemonic_successfully(),
                    message: nil,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .default, handler: { _ in
                    guard let navigationController = self.navigationController else {
                        return
                    }
                    var viewControllers = navigationController.viewControllers
                    viewControllers.removeLast(2)
                    navigationController.setViewControllers(viewControllers, animated: true)
                }))
                present(alert, animated: true)
            } else {
                throw CheckingError.mismatched
            }
        } catch {
            let alert = UIAlertController(
                title: R.string.localizable.mnemonics_mismatched(),
                message: nil,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: R.string.localizable.ok(), style: .cancel))
            present(alert, animated: true)
        }
    }
    
    @objc private func emptyPhrases(_ sender: Any) {
        for inputField in inputFields {
            inputField.textField.text = nil
            inputField.setTextColor(.normal)
        }
        detectPhrases(sender)
    }
    
    @objc private func detectPhrases(_ sender: Any) {
        let phrases = inputFields.map { inputField in
            inputField.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if phrases.contains(where: \.isEmpty) {
            confirmButton.isEnabled = false
        } else {
            confirmButton.isEnabled = true
        }
    }
    
}
