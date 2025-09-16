import UIKit

final class ExplainLightningAddressViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var copyAddressButton: UIButton!
    
    private let address: String
    
    init(address: String) {
        self.address = address
        let nib = R.nib.explainLightningAddressView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        titleLabel.text = R.string.localizable.lightning_address()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 18, weight: .semibold),
            adjustForContentSize: true
        )
        textView.attributedText = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1.1
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: R.color.text_secondary()!,
                .font: UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 14)
                ),
                .paragraphStyle: paragraphStyle,
            ]
            let text = NSMutableAttributedString(
                string: R.string.localizable.lightning_address_explain(address) + "\n\n",
                attributes: attributes
            )
            if let range = text.string.range(of: address) {
                text.addAttribute(
                    .font,
                    value: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14, weight: .medium)
                    ),
                    range: NSRange(range, in: text.string)
                )
            }
            text.append(.orderedList(
                items: [
                    R.string.localizable.lightning_address_explain_1(),
                    R.string.localizable.lightning_address_explain_2(),
                    R.string.localizable.lightning_address_explain_3(),
                ],
                font: UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 14)
                ),
                textColor: { _ in
                    R.color.text_secondary()!
                }
            ))
            text.append(NSAttributedString(
                string: "\n" + R.string.localizable.lightning_address_explain_mao(),
                attributes: attributes
            ))
            var learnMoreAttributes = attributes
            learnMoreAttributes[.link] = URL.lightningAddress
            text.append(NSAttributedString(
                string: R.string.localizable.learn_more(),
                attributes: learnMoreAttributes
            ))
            return text
        }()
        if var config = copyAddressButton.configuration {
            let attributes: AttributeContainer = {
                var container = AttributeContainer()
                container.font = UIFontMetrics.default.scaledFont(
                    for: .systemFont(ofSize: 16, weight: .medium)
                )
                container.foregroundColor = .white
                return container
            }()
            config.attributedTitle = AttributedString(
                R.string.localizable.copy_address(),
                attributes: attributes
            )
            copyAddressButton.configuration = config
        }
    }
    
    @IBAction func copyAddress(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        UIPasteboard.general.string = address
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
}
