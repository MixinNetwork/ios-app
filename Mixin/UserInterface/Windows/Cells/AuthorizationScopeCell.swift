import UIKit

class AuthorizationScopeCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_auth_scope"

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var checkmarkView: CheckmarkView!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }

    func render(name: String, desc: String, forceChecked: Bool) {
        nameLabel.text = name
        descLabel.text = desc
        isUserInteractionEnabled = !forceChecked
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        checkmarkView.status = selected ? .selected : .deselected
    }
}
