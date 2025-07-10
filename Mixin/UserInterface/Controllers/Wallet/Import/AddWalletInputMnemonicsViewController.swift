import UIKit
import MixinServices

final class AddWalletInputMnemonicsViewController: InputMnemonicsViewController {
    
    private let errorDescriptionLabel = {
        let label = UILabel()
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.error_red()
        return label
    }()
    
    private var phrasesCount: BIP39Mnemonics.PhrasesCount = .medium
    private var phraseCountSwitchButtons: [UIButton] = []
    private var mnemonics: BIP39Mnemonics?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItems = [
            .customerService(
                target: self,
                action: #selector(presentCustomerService(_:))
            )
        ]
        titleLabel.text = R.string.localizable.import_mnemonic_phrase()
        descriptionLabel.text = R.string.localizable.enter_mnemonic_phrase(phrasesCount.rawValue)
        titleStackView.setCustomSpacing(32, after: descriptionLabel)
        
        phraseCountSwitchButtons = BIP39Mnemonics.PhrasesCount.allCases
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
        confirmButton.setTitle(R.string.localizable.next(), for: .normal)
        confirmButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .semibold),
            adjustForContentSize: true
        )
        confirmButton.isEnabled = false
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(detectPhrases(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func confirm(_ sender: Any) {
        guard let mnemonics else {
            return
        }
        let fetchAddress = AddWalletFetchAddressViewController(mnemonics: mnemonics)
        navigationController?.pushViewController(fetchAddress, animated: true)
    }
    
    private func reloadInputStackView(count: BIP39Mnemonics.PhrasesCount) {
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
        }
        
        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.distribution = .fillEqually
        rowStackView.spacing = 10
        inputStackView.addArrangedSubview(rowStackView)
        rowStackView.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        addButtonIntoInputFields(
            image: R.image.paste()!,
            title: R.string.localizable.paste(),
            action: #selector(pastePhrases(_:))
        )
        addButtonIntoInputFields(
            image: R.image.explore.web3_send_delete()!,
            title: R.string.localizable.clear(),
            action: #selector(emptyPhrases(_:))
        )
        addSpacerIntoInputFields()
        
        detectPhrases(self)
    }
    
    @objc private func pastePhrases(_ sender: Any) {
        let phrases = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
        guard let phrases else {
            return
        }
        if let count = BIP39Mnemonics.PhrasesCount(rawValue: phrases.count),
           self.phrasesCount != count
        {
            reloadInputStackView(count: count)
        }
        for (index, phrase) in phrases.prefix(inputFields.count).enumerated() {
            let inputField = inputFields[index]
            inputField.setTextColor(phrase: phrase)
            inputField.textField.text = phrase
        }
        detectPhrases(sender)
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
            mnemonics = nil
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = false
        } else {
            do {
                mnemonics = try BIP39Mnemonics(phrases: phrases)
                errorDescriptionLabel.isHidden = true
                confirmButton.isEnabled = true
            } catch {
                mnemonics = nil
                errorDescriptionLabel.text = R.string.localizable.invalid_mnemonic_phrase()
                errorDescriptionLabel.isHidden = false
                confirmButton.isEnabled = false
            }
        }
    }
    
    @objc private func scanMnemonics(_ sender: Any) {
        
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "add_wallet_input_mnemonics"])
    }
    
    @objc private func switchWordCount(_ button: UIButton) {
        guard let count = BIP39Mnemonics.PhrasesCount(rawValue: button.tag) else {
            return
        }
        reloadInputStackView(count: count)
    }
    
    private func wordCountSwitchingButton(count: BIP39Mnemonics.PhrasesCount) -> UIButton {
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
    
}
