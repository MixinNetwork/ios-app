import UIKit

final class ExportImportedSecretIntroductionViewController: IntroductionViewController {
    
    private let secret: ExportingSecret
    
    init(secret: ExportingSecret) {
        self.secret = secret
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let warningObject: String
        switch secret {
        case .mnemonics:
            imageView.image = R.image.mnemonic_phrase()
            actionButton.setTitle(R.string.localizable.show_mnemonic_phrase(), for: .normal)
            warningObject = R.string.localizable.mnemonic_phrases()
        case .privateKeyFromMnemonics, .privateKey:
            imageView.image = R.image.private_key()
            actionButton.setTitle(R.string.localizable.show_private_key(), for: .normal)
            warningObject = R.string.localizable.private_key()
        }
        titleLabel.text = R.string.localizable.before_you_proceed()
        contentLabelTopConstraint.constant = 12
        contentLabel.attributedText = {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .foregroundColor: R.color.text_tertiary()!,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            let text = NSMutableAttributedString(
                string: R.string.localizable.before_you_proceed_desc() + "\n\n\n",
                attributes: attributes
            )
            let items = [
                R.string.localizable.export_mnemonics_warning_1(warningObject),
                R.string.localizable.export_mnemonics_warning_2(warningObject),
                R.string.localizable.export_mnemonics_warning_3(warningObject),
                R.string.localizable.export_mnemonics_warning_4(),
            ]
            let list: NSAttributedString = .orderedList(items: items) { index in
                index < 2 ? R.color.text()! : R.color.error_red()!
            }
            text.append(list)
            return text
        }()
        actionButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        actionButton.addTarget(self, action: #selector(validatePIN(_:)), for: .touchUpInside)
    }
    
    @objc private func validatePIN(_ sender: Any) {
        let validation = ExportImportedSecretValidationViewController(secret: secret)
        navigationController?.pushViewController(replacingCurrent: validation, animated: true)
    }
    
}
