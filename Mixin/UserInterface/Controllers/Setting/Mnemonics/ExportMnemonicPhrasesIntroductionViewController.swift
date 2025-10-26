import UIKit

final class ExportMnemonicPhrasesIntroductionViewController: IntroductionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = R.image.mnemonic_phrase()
        titleLabel.text = R.string.localizable.before_you_proceed()
        contentLabelTopConstraint.constant = 12
        contentTextView.attributedText = {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
                .foregroundColor: R.color.text_tertiary()!,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            let text = NSMutableAttributedString(string: R.string.localizable.export_mnemonics_description() + "\n\n\n", attributes: attributes)
            let items = [
                R.string.localizable.export_mnemonics_instruction_1(),
                R.string.localizable.export_mnemonics_instruction_2(),
                R.string.localizable.export_mnemonics_instruction_3(),
            ]
            let list: NSAttributedString = .orderedList(items: items) { index in
                index < 2 ? R.color.text()! : R.color.error_red()!
            }
            text.append(list)
            return text
        }()
        actionButton.setTitle(R.string.localizable.show_mnemonic_phrase(), for: .normal)
        actionButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
        actionButton.addTarget(self, action: #selector(showPhrases(_:)), for: .touchUpInside)
    }
    
    @objc private func showPhrases(_ sender: Any) {
        let next = ExportMnemonicPhrasesValidationViewController()
        navigationController?.pushViewController(replacingCurrent: next, animated: true)
    }
    
}
