import UIKit
import MixinServices

class SignInWithMnemonicsViewController<PhrasesCount: SignInAvailablePhrasesCount>: UIViewController, MnemonicsViewController {

    @IBOutlet weak var wordsCountSelectorStackView: UIStackView!
    @IBOutlet weak var contentScrollView: UIScrollView!
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var inputStackView: UIStackView!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var signInButton: UIButton!
    
    var inputFields: [MnemonicsInputField] = []
    
    private(set) var phrasesCount: PhrasesCount
    private(set) var phraseCountSwitchButtons: [UIButton] = []
    private(set) var mnemonicsInputHandler: MnemonicsInputHandler!
    
    init(phrasesCount: PhrasesCount) {
        self.phrasesCount = phrasesCount
        let nib = R.nib.signInWithMnemonicsView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.sign_in()
        mnemonicsInputHandler = MnemonicsInputHandler(viewController: self)
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        phraseCountSwitchButtons = PhrasesCount.allCases.map(
            wordCountSwitchingButton(count:)
        )
        phraseCountSwitchButtons.forEach(
            wordsCountSelectorStackView.addArrangedSubview(_:)
        )
        
        reloadViews(count: phrasesCount)
        signInButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.sign_in_with_mnemonic_phrase(),
            scalingByFontSize: 16,
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(detectPhrases(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @IBAction func signIn(_ sender: Any) {
        
    }
    
    func reloadViews(count: PhrasesCount) {
        view.endEditing(true)
        self.phrasesCount = count
        let selectedTag = count.rawValue
        for button in phraseCountSwitchButtons {
            button.isSelected = button.tag == selectedTag
        }
        inputFields.removeAll()
        for view in inputStackView.subviews {
            view.removeFromSuperview()
        }
        
        addTextFields(backgroundColor: .primary, count: count.rawValue)
        for textField in inputFields.map(\.textField) {
            if textField.tag == count.rawValue - 1 {
                textField.returnKeyType = .done
            } else {
                textField.returnKeyType = .next
            }
            textField.clearButtonMode = .whileEditing
            textField.delegate = mnemonicsInputHandler
            textField.deleteDelegate = mnemonicsInputHandler
        }
        
        detectPhrases(self)
    }
    
    func arePhrasesValid(_ phrases: [String]) -> Bool {
        false
    }
    
    @objc func scanQRCode(_ sender: Any) {
        let scanner = QRCodeScannerViewController()
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
    @objc func pastePhrases(_ sender: Any) {
        let phrases = UIPasteboard.general.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
        guard let phrases else {
            return
        }
        input(phrases: phrases)
    }
    
    @objc func emptyPhrases(_ sender: Any) {
        for inputField in inputFields {
            inputField.textField.text = nil
            inputField.setTextColor(.normal)
        }
        detectPhrases(sender)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "login_mnemonic_phrase"])
    }
    
    @objc private func switchWordCount(_ button: UIButton) {
        if let count = PhrasesCount(rawValue: button.tag) {
            reloadViews(count: count)
        }
        view.endEditing(true)
    }
    
    @objc private func detectPhrases(_ sender: Any) {
        let phrases = self.textFieldPhrases
        if phrases.contains(where: \.isEmpty) {
            errorDescriptionLabel.text = nil
            signInButton.isEnabled = false
        } else if arePhrasesValid(phrases) {
            errorDescriptionLabel.text = nil
            signInButton.isEnabled = true
        } else {
            errorDescriptionLabel.text = R.string.localizable.invalid_mnemonic_phrase()
            signInButton.isEnabled = false
        }
    }
    
    private func input(phrases: [String]) {
        guard let count = PhrasesCount(rawValue: phrases.count) else {
            return
        }
        if self.phrasesCount != count {
            reloadViews(count: count)
        }
        for (index, phrase) in phrases.prefix(inputFields.count).enumerated() {
            let inputField = inputFields[index]
            inputField.setTextColor(phrase: phrase)
            inputField.textField.text = phrase
        }
        detectPhrases(self)
    }
    
    private func wordCountSwitchingButton(count: PhrasesCount) -> UIButton {
        let button = ConfigurationBasedOutlineButton(type: .system)
        button.configuration = {
            var config: UIButton.Configuration = .bordered()
            config.cornerStyle = .capsule
            config.attributedTitle = AttributedString(
                string: R.string.localizable.number_of_words(count.rawValue),
                scalingByFontSize: 14,
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

extension SignInWithMnemonicsViewController: NavigationBarStyling {
    
    var navigationBarStyle: NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension SignInWithMnemonicsViewController: QRCodeScannerViewControllerDelegate {
    
    func qrCodeScannerViewController(_ controller: QRCodeScannerViewController, shouldRecognizeString string: String) -> Bool {
        let phrases = string.components(separatedBy: " ")
        input(phrases: phrases)
        return false
    }
    
}
