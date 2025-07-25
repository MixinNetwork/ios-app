import UIKit

final class PrivateKeyViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var keyBackgroundView: UIView!
    @IBOutlet weak var keyLabel: UILabel!
    @IBOutlet weak var footerStackView: UIStackView!
    @IBOutlet weak var doneButton: UIButton!
    
    private let privateKey: String
    
    init(privateKey: String) {
        self.privateKey = privateKey
        let nib = R.nib.privateKeyView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.your_private_key()
        descriptionLabel.text = R.string.localizable.write_down_secret_description()
        keyBackgroundView.layer.cornerRadius = 8
        keyBackgroundView.layer.masksToBounds = true
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.usesDefaultHyphenation = false
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: UIFontMetrics.default.scaledFont(
                for: .monospacedSystemFont(ofSize: 16, weight: .regular)
            ),
            .foregroundColor: R.color.text()!,
        ]
        keyLabel.attributedText = NSAttributedString(string: privateKey, attributes: attributes)
        let footerTexts = [
            R.string.localizable.mnemonic_phrase_tip_1(),
            R.string.localizable.mnemonic_phrase_tip_2(),
        ]
        footerTexts.forEach(addTextInFooter(text:))
        if var config = doneButton.configuration {
            config.titleTextAttributesTransformer = .init { incoming in
                var outgoing = incoming
                outgoing.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
                return outgoing
            }
            config.title = R.string.localizable.done()
            doneButton.configuration = config
        }
    }
    
    @IBAction func copyPrivateKey(_ sender: Any) {
        UIPasteboard.general.string = privateKey
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
    @IBAction func done(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    private func addTextInFooter(text: String) {
        let label = UILabel()
        label.textColor = R.color.text_tertiary()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.numberOfLines = 0
        footerStackView.addArrangedSubview(label)
        label.text = text
    }
    
}
