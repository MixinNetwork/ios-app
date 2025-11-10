import UIKit
import MixinServices

final class ApplyReferralCodePreviewViewController: AuthenticationPreviewViewController {
    
    private let code: String
    private let precentage: String
    private let inviter: UserItem
    
    init(code: String, precentage: String, inviter: UserItem) {
        self.code = code
        self.precentage = precentage
        self.inviter = inviter
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.backgroundColor = R.color.background_quaternary()
        tableView.allowsSelection = false
        tableHeaderView.setIcon { imageView in
            imageView.image = R.image.referral_preview()
        }
        layoutTableHeaderViewByDefault()
        
        reloadData(with: [
            .boldInfo(caption: .string(R.string.localizable.referral_code()), content: code),
            .boldInfo(caption: .string(R.string.localizable.invitee_commission()), content: precentage),
            .user(title: R.string.localizable.inviter(), user: inviter),
        ])
        
        trayView?.backgroundColor = R.color.background_quaternary()
    }
    
    override func loadTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
    }
    
    override func layoutTableHeaderView() {
        tableHeaderView.style = .insetted(margin: tableView.layoutMargins.left)
        super.layoutTableHeaderView()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch cell {
        case let cell as AuthenticationPreviewInfoCell:
            cell.contentLeadingConstraint.constant = 16
            cell.contentTrailingConstraint.constant = 16
        case let cell as AuthenticationPreviewCompactInfoCell:
            cell.contentLeadingConstraint.constant = 16
            cell.contentTrailingConstraint.constant = 16
        case let cell as PaymentUserGroupCell:
            cell.contentLeadingConstraint.constant = 16
            cell.contentTrailingConstraint.constant = 16
        default:
            break
        }
        return cell
    }
    
    override func confirm(_ sender: Any) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        layoutTableHeaderViewByDefault()
        ReferralAPI.bindReferral(code: code) { [weak self] result in
            guard let self else {
                return
            }
            self.canDismissInteractively = true
            switch result {
            case .success:
                self.tableHeaderView.setIcon(progress: .success)
                self.tableHeaderView.titleLabel.text = R.string.localizable.apply_referral_code()
                self.tableView.setContentOffset(.zero, animated: true)
                self.loadSingleButtonTrayView(
                    title: R.string.localizable.done(),
                    action: #selector(close(_:))
                )
                self.trayView?.backgroundColor = R.color.background_quaternary()
            case .failure(let error):
                self.tableHeaderView.setIcon(progress: .failure)
                self.layoutTableHeaderView(
                    title: R.string.localizable.referral_code_applying_failed(),
                    subtitle: error.localizedDescription,
                    style: .destructive
                )
                self.tableView.setContentOffset(.zero, animated: true)
                self.loadDoubleButtonTrayView(
                    leftTitle: R.string.localizable.cancel(),
                    leftAction: #selector(close(_:)),
                    rightTitle: R.string.localizable.retry(),
                    rightAction: #selector(confirm(_:)),
                    animation: .vertical
                )
                self.trayView?.backgroundColor = R.color.background_quaternary()
            }
        }
    }
    
    private func layoutTableHeaderViewByDefault() {
        tableHeaderView.titleLabel.text = R.string.localizable.apply_referral_code()
        tableHeaderView.subtitleTextView.attributedText = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let text = NSMutableAttributedString(
                string: R.string.localizable.referral_code_applied_header(),
                attributes: [
                    .font: UIFontMetrics.default.scaledFont(
                        for: .systemFont(ofSize: 14)
                    ),
                    .foregroundColor: R.color.text()!,
                    .paragraphStyle: paragraphStyle,
                ]
            )
            let learnMoreRange = text.string.range(
                of: R.string.localizable.learn_more(),
                options: [.backwards, .caseInsensitive]
            )
            if let learnMoreRange {
                let linkRange = NSRange(learnMoreRange, in: text.string)
                text.addAttributes(
                    [.foregroundColor: R.color.theme()!, .link: URL.referral],
                    range: linkRange
                )
            }
            return text
        }()
        layoutTableHeaderView()
    }
    
}
