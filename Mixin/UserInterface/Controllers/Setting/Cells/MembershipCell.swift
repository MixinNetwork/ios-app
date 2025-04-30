import UIKit

final class MembershipCell: UITableViewCell {
    
    protocol Delegate: AnyObject {
        func membershipCellDidSelectViewPlan(_ cell: MembershipCell)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var membershipStackView: UIStackView!
    @IBOutlet weak var membershipLabel: UILabel!
    @IBOutlet weak var expirationLabel: UILabel!
    @IBOutlet weak var viewPlanButton: UIButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(14, after: membershipStackView)
    }
    
    @IBAction func viewPlan(_ sender: Any) {
        delegate?.membershipCellDidSelectViewPlan(self)
    }
    
}
