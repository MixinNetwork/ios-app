import UIKit
import MixinServices

protocol PaymentUserGroupCellDelegate: AnyObject {
    func paymentUserGroupCell(_ cell: PaymentUserGroupCell, didSelectMessengerUser item: UserItem)
}

final class PaymentUserGroupCell: UITableViewCell {
    
    enum CheckmarkCondition {
        case never
        case byUserID(Set<String>)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    weak var delegate: PaymentUserGroupCellDelegate?
    
    private var users: [UserItem] = []
    private var itemViews: [PaymentUserItemView] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(7, after: captionLabel)
    }
    
    func reloadUsers(with users: [UserItem], checkmarkCondition: CheckmarkCondition) {
        self.users = users
        let numberOfItemViewsToBeAdded = users.count - itemViews.count
        if numberOfItemViewsToBeAdded > 0 {
            for _ in 0..<numberOfItemViewsToBeAdded {
                let view = R.nib.paymentUserItemView(withOwner: nil)!
                view.button.addTarget(self, action: #selector(reportSelection(_:)), for: .touchUpInside)
                contentStackView.addArrangedSubview(view)
                itemViews.append(view)
            }
        } else if numberOfItemViewsToBeAdded < 0 {
            for itemView in contentStackView.arrangedSubviews.suffix(-numberOfItemViewsToBeAdded) {
                itemView.removeFromSuperview()
            }
            itemViews.removeLast(-numberOfItemViewsToBeAdded)
        }
        for (i, user) in users.enumerated() {
            let itemView = itemViews[i]
            itemView.load(user: user)
            switch checkmarkCondition {
            case .never:
                itemView.checkmark = nil
            case .byUserID(let ids):
                itemView.checkmark = ids.contains(user.userId) ? .yes : .no
            }
            itemView.button.tag = i
        }
    }
    
    @objc private func reportSelection(_ sender: UIButton) {
        let user = users[sender.tag]
        if user.isCreatedByMessenger {
            delegate?.paymentUserGroupCell(self, didSelectMessengerUser: user)
        }
    }
    
}
