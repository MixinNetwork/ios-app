import UIKit
import MixinServices

final class ViewMnemonicsViewController: MnemonicsViewController {
    
    private let mnemonics: Mnemonics
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    init(mnemonics: Mnemonics) {
        self.mnemonics = mnemonics
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.write_down_mnemonic_phrase()
        descriptionLabel.text = R.string.localizable.write_down_mnemonic_phrase_desc()
        addTextFields(count: mnemonics.phrases.count)
        addSpacerIntoInputFields()
        addButtonIntoInputFields(
            image: R.image.web.ic_action_copy()!,
            title: R.string.localizable.copy(),
            action: #selector(copyPhrases(_:))
        )
        for (index, phrase) in mnemonics.phrases.enumerated() {
            let textField = textFields[index]
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
        confirmButton.setTitle(R.string.localizable.check_backup(), for: .normal)
        confirmButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .semibold), adjustForContentSize: true)
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
        let check = CheckMnemonicsViewController(mnemonics: mnemonics)
        navigationController?.pushViewController(check, animated: true)
    }
    
    @objc private func copyPhrases(_ sender: Any) {
        UIPasteboard.general.string = mnemonics.phrases.joined(separator: " ")
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
