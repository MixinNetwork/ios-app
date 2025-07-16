import UIKit

final class ExportImportedMnemonicsViewController: MnemonicsViewController {
    
    private let mnemonics: BIP39Mnemonics
    
    init(mnemonics: BIP39Mnemonics) {
        self.mnemonics = mnemonics
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.your_mnemonic_phrase()
        descriptionLabel.text = R.string.localizable.write_down_mnemonic_phrase_desc()
        addTextFields(count: mnemonics.phrases.count)
        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.distribution = .fillEqually
        rowStackView.spacing = 10
        inputStackView.addArrangedSubview(rowStackView)
        rowStackView.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        addButtonIntoInputFields(
            image: R.image.ic_user_qr_code()!,
            title: R.string.localizable.qr_code(),
            action: #selector(showQRCode(_:))
        )
        addButtonIntoInputFields(
            image: R.image.web.ic_action_copy()!,
            title: R.string.localizable.copy(),
            action: #selector(copyPhrases(_:))
        )
        addSpacerIntoInputFields()
        for (index, phrase) in mnemonics.phrases.enumerated() {
            let textField = inputFields[index].textField
            textField.text = phrase
            textField.isUserInteractionEnabled = false
        }
        let footerTexts = [
            R.string.localizable.mnemonic_phrase_tip_1(),
            R.string.localizable.mnemonic_phrase_tip_2(),
        ]
        for text in footerTexts {
            let label = UILabel()
            label.textColor = R.color.text_tertiary()
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            label.numberOfLines = 0
            footerStackView.addArrangedSubview(label)
            label.text = text
        }
        footerStackViewBottomConstraint.constant = 30
        confirmButton.setTitle(R.string.localizable.done(), for: .normal)
        confirmButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .semibold),
            adjustForContentSize: true
        )
    }
    
    override func adjustScrollViewContentInsets(_ notification: Notification) {
        // This function is called when keyboard changes its frame.
        // This view controller usually shows after PIN validation, which keyboard hides on disappear,
        // and that would affect our view controller, causing weird animation.
        // Override this function to reduce that.
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        contentViewHeightConstraint.priority = .defaultLow
        UIView.performWithoutAnimation(view.layoutIfNeeded)
    }
    
    override func confirm(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func showQRCode(_ sender: Any) {
        let code = MnemonicsQRCodeViewController(string: mnemonics.joinedPhrases)
        present(code, animated: true)
    }
    
    @objc private func copyPhrases(_ sender: Any) {
        UIPasteboard.general.string = mnemonics.joinedPhrases
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
