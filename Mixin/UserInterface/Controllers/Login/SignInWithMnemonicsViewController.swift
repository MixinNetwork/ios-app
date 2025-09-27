import UIKit
import MixinServices
import TIP

final class SignInWithMnemonicsViewController: InputMnemonicsViewController {
    
    private(set) var phrasesCount: MixinMnemonics.PhrasesCount = .default
    
    private var phraseCountSwitchButtons: [UIButton] = []
    
    private let errorDescriptionLabel = {
        let label = UILabel()
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.error_red()
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        
        titleLabel.text = R.string.localizable.sign_in_with_mnemonic_phrase()
        descriptionLabel.text = R.string.localizable.enter_mnemonic_phrase(phrasesCount.rawValue)
        titleStackView.setCustomSpacing(32, after: descriptionLabel)
        
        phraseCountSwitchButtons = MixinMnemonics.PhrasesCount.allCases
            .map(wordCountSwitchingButton(count:))
        for button in phraseCountSwitchButtons {
            button.layer.cornerRadius = button.bounds.height / 2
        }
        let stackView = UIStackView(arrangedSubviews: phraseCountSwitchButtons)
        stackView.axis = .horizontal
        stackView.spacing = 11
        titleStackView.addArrangedSubview(stackView)
        let spacer = UIView()
        spacer.backgroundColor = .clear
        stackView.addArrangedSubview(spacer)
        
        inputStackViewTopConstraint.constant = 20
        reloadInputStackView(count: phrasesCount)
        
        footerStackView.addArrangedSubview(errorDescriptionLabel)
        confirmButton.setTitle(R.string.localizable.confirm(), for: .normal)
        confirmButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .semibold), adjustForContentSize: true)
        confirmButton.isEnabled = false
        NotificationCenter.default.addObserver(self, selector: #selector(detectPhrases(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func confirm(_ sender: Any) {
        do {
            let mnemonics = try MixinMnemonics(phrases: textFieldPhrases)
            let login = LoginWithMnemonicViewController(action: .signIn(mnemonics))
            navigationController?.pushViewController(login, animated: true)
        } catch {
            errorDescriptionLabel.text = R.string.localizable.invalid_mnemonic_phrase()
            errorDescriptionLabel.isHidden = false
            confirmButton.isEnabled = false
        }
    }
    
    func reloadInputStackView(count: MixinMnemonics.PhrasesCount) {
        self.phrasesCount = count
        
        descriptionLabel.text = R.string.localizable.enter_mnemonic_phrase(count.rawValue)
        for button in phraseCountSwitchButtons {
            button.isSelected = button.tag == phrasesCount.rawValue
        }
        
        inputFields.removeAll()
        for view in inputStackView.subviews {
            view.removeFromSuperview()
        }
        addTextFields(count: count.rawValue)
        for textField in inputFields.map(\.textField) {
            if textField.tag == count.rawValue - 1 {
                textField.returnKeyType = .done
            } else {
                textField.returnKeyType = .next
            }
            textField.clearButtonMode = .whileEditing
            textField.delegate = self
            textField.deleteDelegate = self
        }
        
        addButtonIntoInputFields(
            image: R.image.explore.web3_send_scan()!,
            title: R.string.localizable.scan(),
            action: #selector(scanQRCode(_:))
        )
        addButtonIntoInputFields(
            image: R.image.paste()!,
            title: R.string.localizable.paste(),
            action: #selector(pastePhrases(_:))
        )
        addRowStackViewForButtonsIntoInputStackView()
        addButtonIntoInputFields(
            image: R.image.explore.web3_send_delete()!,
            title: R.string.localizable.clear(),
            action: #selector(emptyPhrases(_:))
        )
        detectPhrases(self)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "login_mnemonic_phrase"])
    }
    
    @objc private func switchWordCount(_ button: UIButton) {
        guard let count = MixinMnemonics.PhrasesCount(rawValue: button.tag) else {
            return
        }
        view.endEditing(true)
        reloadInputStackView(count: count)
    }
    
    @objc private func scanQRCode(_ sender: Any) {
        let scanner = CameraViewController.instance()
        scanner.asQrCodeScanner = true
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
    @objc private func pastePhrases(_ sender: Any) {
        let phrases = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
        guard let phrases else {
            return
        }
        input(phrases: phrases)
    }
    
    @objc private func emptyPhrases(_ sender: Any) {
        for inputField in inputFields {
            inputField.textField.text = nil
            inputField.setTextColor(.normal)
        }
        detectPhrases(sender)
    }
    
    @objc private func detectPhrases(_ sender: Any) {
        let phrases = self.textFieldPhrases
        if phrases.contains(where: \.isEmpty) {
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = false
        } else if MixinMnemonics.areValid(phrases: phrases) {
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = true
        } else {
            errorDescriptionLabel.text = R.string.localizable.invalid_mnemonic_phrase()
            errorDescriptionLabel.isHidden = false
            confirmButton.isEnabled = false
        }
    }
    
    private func wordCountSwitchingButton(count: MixinMnemonics.PhrasesCount) -> UIButton {
        let button = ConfigurationBasedOutlineButton(type: .system)
        button.configuration = {
            var config: UIButton.Configuration = .bordered()
            config.cornerStyle = .capsule
            config.attributedTitle = AttributedString(
                R.string.localizable.number_of_words(count.rawValue),
                attributes: AttributeContainer([
                    .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
                ])
            )
            config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
            return config
        }()
        button.tag = count.rawValue
        button.addTarget(self, action: #selector(switchWordCount(_:)), for: .touchUpInside)
        button.isSelected = count == phrasesCount
        return button
    }
    
    private func input(phrases: [String]) {
        if let count = MixinMnemonics.PhrasesCount(rawValue: phrases.count),
           self.phrasesCount != count
        {
            reloadInputStackView(count: count)
        }
        for (index, phrase) in phrases.prefix(inputFields.count).enumerated() {
            let inputField = inputFields[index]
            inputField.setTextColor(phrase: phrase)
            inputField.textField.text = phrase
        }
        detectPhrases(self)
    }
    
}

extension SignInWithMnemonicsViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        let phrases = string.components(separatedBy: " ")
        input(phrases: phrases)
        return false
    }
    
}
