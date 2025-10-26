import UIKit

final class CrossWalletTransactionFreeIntroductionViewController: IntroductionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            20
        case .medium:
            30
        case .long:
            50
        case .extraLong:
            70
        }
        imageView.image = R.image.transaction_fee()
        titleLabel.text = R.string.localizable.limited_time_free()
        contentLabel.attributedText = {
            let text = NSMutableAttributedString(
                string: R.string.localizable.limited_time_free_condition() + "\n\n",
                attributes: [
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.text()!,
                ]
            )
            text.append(
                .orderedList(
                    items: [
                        R.string.localizable.limited_time_free_condition_1(),
                        R.string.localizable.limited_time_free_condition_2(),
                    ],
                    font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                ) {
                    _ in R.color.text_secondary()!
                }
            )
            text.append(
                NSAttributedString(
                    string: "\n" + R.string.localizable.limited_time_free_description(),
                    attributes: [
                        .font: UIFontMetrics.default.scaledFont(
                            for: .systemFont(ofSize: 14)
                        ),
                        .foregroundColor: R.color.text_secondary()!,
                    ]
                )
            )
            let learnMoreRange = text.string.range(
                of: R.string.localizable.learn_more(),
                options: [.backwards, .caseInsensitive]
            )
            if let learnMoreRange {
                let linkRange = NSRange(learnMoreRange, in: text.string)
                text.addAttributes(
                    [.foregroundColor: R.color.theme()!, .link: URL.crossWalletTransactionFree],
                    range: linkRange
                )
            }
            return text
        }()
        actionButton.setTitle(R.string.localizable.got_it(), for: .normal)
        actionButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        actionButton.addTarget(self, action: #selector(gotIt(_:)), for: .touchUpInside)
    }
    
    @objc private func gotIt(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}
