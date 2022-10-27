import UIKit

class AuthorizationScopeCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var checkmarkView: CheckmarkView!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkmarkView.status = selected ? .selected : .deselected
    }
    
    func render(item: Scope.ItemInfo) {
        titleLabel.text = item.title
        descLabel.text = item.desc
        setSelected(item.isSelected, animated: false)
    }
    
}
