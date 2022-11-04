import UIKit

class AuthorizationScopeCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var checkmarkView: CheckmarkView!
    
    private var forceChecked = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if forceChecked {
            checkmarkView.status = .nonSelectable
        } else {
            checkmarkView.status = selected ? .selected : .deselected
        }
    }
    
    func render(scope: AuthorizationScope, isSelected: Bool, forceChecked: Bool) {
        titleLabel.text = scope.title
        descLabel.text = scope.description
        self.forceChecked = forceChecked
        setSelected(isSelected, animated: false)
        isUserInteractionEnabled = !forceChecked
    }
    
}
