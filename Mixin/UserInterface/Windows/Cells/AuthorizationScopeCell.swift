import UIKit

class AuthorizationScopeCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_auth_scope"

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var selectionImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView()
    }

    func render(name: String, desc: String) {
        nameLabel.text = name
        descLabel.text = desc
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        selectionImageView.image = selected ? #imageLiteral(resourceName: "ic_member_selected") : #imageLiteral(resourceName: "ic_member_not_selected")
    }
}
