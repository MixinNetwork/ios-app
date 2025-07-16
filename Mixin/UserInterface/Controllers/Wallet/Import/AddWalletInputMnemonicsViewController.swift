import UIKit
import MixinServices

final class AddWalletInputMnemonicsViewController: InputMnemonicsViewController {
    
    private let mnemonicsEncryptionKey: Data
    
    private weak var errorDescriptionLabel: UILabel!
    
    private var phrasesCount: BIP39Mnemonics.PhrasesCount = .medium
    private var phraseCountSwitchButtons: [UIButton] = []
    private var mnemonics: (plain: BIP39Mnemonics, encrypted: EncryptedBIP39Mnemonics)?
    private var eliminateLayoutAnimations = true
    
    init(mnemonicsEncryptionKey: Data) {
        self.mnemonicsEncryptionKey = mnemonicsEncryptionKey
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
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
        
        let errorDescriptionLabel = UILabel()
        errorDescriptionLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        errorDescriptionLabel.adjustsFontForContentSizeCategory = true
        errorDescriptionLabel.textColor = R.color.error_red()
        footerStackView.addArrangedSubview(errorDescriptionLabel)
        self.errorDescriptionLabel = errorDescriptionLabel
        
        inputStackViewTopConstraint.constant = 20
        reloadInputStackView(count: phrasesCount)
        
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        eliminateLayoutAnimations = false
    }
    
    override func confirm(_ sender: Any) {
        guard let mnemonics else {
            return
        }
        let fetchAddress = AddWalletFetchAddressViewController(
            mnemonics: mnemonics.plain,
            encryptedMnemonics: mnemonics.encrypted
        )
        navigationController?.pushViewController(fetchAddress, animated: true)
    }
    
    override func adjustScrollViewContentInsets(_ notification: Notification) {
        if eliminateLayoutAnimations {
            UIView.performWithoutAnimation {
                super.adjustScrollViewContentInsets(notification)
            }
        } else {
            super.adjustScrollViewContentInsets(notification)
        }
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
            image: R.image.explore.web3_send_scan()!,
            title: R.string.localizable.scan(),
            action: #selector(scanQRCode(_:))
        )
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
        
        detectPhrases(self)
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
            mnemonics = nil
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = false
        } else {
            do {
                let plain = try BIP39Mnemonics(phrases: phrases)
                let encrypted = try EncryptedBIP39Mnemonics(
                    mnemonics: plain,
                    key: mnemonicsEncryptionKey
                )
                mnemonics = (plain: plain, encrypted: encrypted)
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
    
    private func input(phrases: [String]) {
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
        detectPhrases(self)
    }
    
}

extension AddWalletInputMnemonicsViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        let phrases = string.components(separatedBy: " ")
        input(phrases: phrases)
        return false
    }
    
}
