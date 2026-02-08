import UIKit
import MixinServices
import TIP

final class SignInWithMnemonicsViewController: InputMnemonicsViewController {
    
    private(set) var phrasesCount: MixinMnemonics.PhrasesCount? = .default
    
    private var phraseCountSwitchButtons: [UIButton] = []
    
    private let unavailablePhrasesCountTag = -1
    
    private let errorDescriptionLabel = {
        let label = UILabel()
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = R.color.error_red()
        return label
    }()
    
    private lazy var signUpHintLabel = {
        let label = UILabel()
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = R.color.text_quaternary()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = R.string.localizable.sign_up_15_secs()
        signUpHintLabelIfLoaded = label
        return label
    }()
    
    private weak var signUpHintLabelIfLoaded: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        scrollView.isDirectionalLockEnabled = true
        titleLabel.text = R.string.localizable.sign_in_with_mnemonic_phrase()
        descriptionLabel.text = R.string.localizable.mnemonics_policy()
        titleStackView.setCustomSpacing(32, after: descriptionLabel)
        
        phraseCountSwitchButtons = MixinMnemonics.PhrasesCount.allCases
            .map(wordCountSwitchingButton(count:))
        phraseCountSwitchButtons.append(wordCountSwitchingButton(count: nil))
        let stackView = UIStackView(arrangedSubviews: phraseCountSwitchButtons)
        stackView.axis = .horizontal
        stackView.spacing = 11
        stackView.distribution = .fillProportionally
        let buttonsScrollView = UIScrollView()
        buttonsScrollView.isDirectionalLockEnabled = true
        buttonsScrollView.showsHorizontalScrollIndicator = false
        buttonsScrollView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(buttonsScrollView.contentLayoutGuide)
            make.height.equalTo(buttonsScrollView.frameLayoutGuide.snp.height)
        }
        titleStackView.addArrangedSubview(buttonsScrollView)
        
        inputStackViewTopConstraint.constant = 20
        reloadViews(count: phrasesCount)
        
        footerStackView.addArrangedSubview(errorDescriptionLabel)
        confirmButton.setTitle(R.string.localizable.confirm(), for: .normal)
        confirmButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .semibold),
            adjustForContentSize: true
        )
        confirmButton.isEnabled = false
        NotificationCenter.default.addObserver(self, selector: #selector(detectPhrases(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func confirm(_ sender: Any) {
        if phrasesCount == nil {
            let intro = CreateAccountIntroductionViewController()
            present(intro, animated: true)
        } else {
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
    }
    
    func reloadViews(count: MixinMnemonics.PhrasesCount?) {
        self.phrasesCount = count
        let selectedTag = count?.rawValue ?? unavailablePhrasesCountTag
        for button in phraseCountSwitchButtons {
            button.isSelected = button.tag == selectedTag
        }
        inputFields.removeAll()
        for view in inputStackView.subviews {
            view.removeFromSuperview()
        }
        
        if let count {
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
            
            confirmButton.setTitle(R.string.localizable.confirm(), for: .normal)
            UIView.performWithoutAnimation(confirmButton.layoutIfNeeded)
            signUpHintLabelIfLoaded?.removeFromSuperview()
            detectPhrases(self)
        } else {
            let textView = UITextView()
            textView.backgroundColor = R.color.background_input()
            textView.layer.cornerRadius = 8
            textView.layer.masksToBounds = true
            textView.textContainer.lineFragmentPadding = 0
            textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            textView.isScrollEnabled = false
            textView.attributedText = .importWalletGuide()
            inputStackView.addArrangedSubview(textView)
            
            confirmButton.setTitle(R.string.localizable.create_an_account(), for: .normal)
            UIView.performWithoutAnimation(confirmButton.layoutIfNeeded)
            confirmButton.isEnabled = true
            if signUpHintLabelIfLoaded?.superview == nil {
                actionStackView.addArrangedSubview(signUpHintLabel)
            }
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "login_mnemonic_phrase"])
    }
    
    @objc private func switchWordCount(_ button: UIButton) {
        if let count = MixinMnemonics.PhrasesCount(rawValue: button.tag) {
            reloadViews(count: count)
        } else {
            reloadViews(count: nil)
        }
        view.endEditing(true)
    }
    
    @objc private func scanQRCode(_ sender: Any) {
        let scanner = QRCodeScannerViewController()
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
    
    private func wordCountSwitchingButton(count: MixinMnemonics.PhrasesCount?) -> UIButton {
        let button = ConfigurationBasedOutlineButton(type: .system)
        let title = if let count {
            R.string.localizable.number_of_words(count.rawValue)
        } else {
            R.string.localizable.unavailable_mnemonics_word_count()
        }
        button.configuration = {
            var config: UIButton.Configuration = .bordered()
            config.cornerStyle = .capsule
            config.attributedTitle = AttributedString(
                title,
                attributes: AttributeContainer([
                    .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
                ])
            )
            config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
            return config
        }()
        button.tag = count?.rawValue ?? unavailablePhrasesCountTag
        button.addTarget(self, action: #selector(switchWordCount(_:)), for: .touchUpInside)
        button.isSelected = count == phrasesCount
        return button
    }
    
    private func input(phrases: [String]) {
        if let count = MixinMnemonics.PhrasesCount(rawValue: phrases.count) {
            if self.phrasesCount != count {
                reloadViews(count: count)
            }
            for (index, phrase) in phrases.prefix(inputFields.count).enumerated() {
                let inputField = inputFields[index]
                inputField.setTextColor(phrase: phrase)
                inputField.textField.text = phrase
            }
            detectPhrases(self)
        } else {
            reloadViews(count: nil)
        }
    }
    
}

extension SignInWithMnemonicsViewController: QRCodeScannerViewControllerDelegate {
    
    func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, shouldRecognizeString string: String) -> Bool {
        let phrases = string.components(separatedBy: " ")
        input(phrases: phrases)
        return false
    }
    
}
