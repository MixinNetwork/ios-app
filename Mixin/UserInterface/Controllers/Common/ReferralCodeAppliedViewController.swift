import UIKit
import MixinServices

final class ReferralCodeAppliedViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var introductionsLabel: UILabel!
    @IBOutlet weak var footerTextView: UITextView!
    @IBOutlet weak var gotItButton: UIButton!
    @IBOutlet weak var upgradePlanButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.referral_code_applied()
        headerLabel.text = R.string.localizable.referral_code_applied_header()
        headerLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        introductionsLabel.attributedText = .orderedList(
            items: [
                R.string.localizable.referral_code_applied_introduction_1(),
                R.string.localizable.referral_code_applied_introduction_2(),
                R.string.localizable.referral_code_applied_introduction_3(),
            ],
            font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
            paragraphSpacing: 10,
        ) { _ in
            R.color.text()!
        }
        footerTextView.textContainerInset = .zero
        footerTextView.textContainer.lineFragmentPadding = 0
        footerTextView.attributedText = {
            let text = NSMutableAttributedString(
                string: R.string.localizable.referral_code_applied_footer(),
                attributes: [
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.text()!,
                ]
            )
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
        
        gotItButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = .white
            return AttributedString(
                R.string.localizable.got_it(),
                attributes: attributes
            )
        }()
        gotItButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        upgradePlanButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = R.color.theme()
            return AttributedString(
                R.string.localizable.upgrade_plan(),
                attributes: attributes
            )
        }()
        upgradePlanButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func upgradePlan(_ sender: Any) {
        guard let presentingViewController else {
            return
        }
        presentingViewController.dismiss(animated: true) {
            let buy = MembershipPlansViewController(selectedPlan: nil)
            presentingViewController.present(buy, animated: true)
        }
    }
    
}
