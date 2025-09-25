import UIKit

final class ReferralIntroductionViewController: UIViewController {
    
    @IBOutlet weak var textStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var introductionsLabel: UILabel!
    @IBOutlet weak var footerTextView: UITextView!
    @IBOutlet weak var upgradeNowButton: UIButton!
    @IBOutlet weak var notNowButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = R.string.localizable.referral_program()
        textStackView.setCustomSpacing(24, after: titleLabel)
        
        headerLabel.text = R.string.localizable.referral_program_introduction_header()
        headerLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        textStackView.setCustomSpacing(16, after: headerLabel)
        
        introductionsLabel.attributedText = .orderedList(
            items: [
                R.string.localizable.referral_program_introduction_1(),
                R.string.localizable.referral_program_introduction_2(),
                R.string.localizable.referral_program_introduction_3(),
            ],
            font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
            paragraphSpacing: 10,
        ) { _ in
            R.color.text_secondary()!
        }
        introductionsLabel.adjustsFontForContentSizeCategory = true
        textStackView.setCustomSpacing(32, after: introductionsLabel)
        
        footerTextView.textContainerInset = .zero
        footerTextView.textContainer.lineFragmentPadding = 0
        footerTextView.attributedText = {
            let text = NSMutableAttributedString()
            let footer = NSAttributedString(
                string: R.string.localizable.referral_program_introduction_footer(),
                attributes: [
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.text()!,
                ]
            )
            text.append(footer)
            
            let learnMore = NSAttributedString(
                string: R.string.localizable.learn_more(),
                attributes: [
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.theme()!,
                    .link: URL.referral,
                ]
            )
            text.append(learnMore)
            
            return text
        }()
        footerTextView.adjustsFontForContentSizeCategory = true
        
        upgradeNowButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = .white
            return AttributedString(
                R.string.localizable.upgrade_membership_now(),
                attributes: attributes
            )
        }()
        upgradeNowButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        notNowButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = R.color.theme()
            return AttributedString(
                R.string.localizable.not_now(),
                attributes: attributes
            )
        }()
        notNowButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func upgradeNow(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        presentingViewController.dismiss(animated: true) {
            let buy = MembershipPlansViewController(selectedPlan: nil)
            presentingViewController.present(buy, animated: true)
        }
    }
    
    @IBAction func notNow(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
}
