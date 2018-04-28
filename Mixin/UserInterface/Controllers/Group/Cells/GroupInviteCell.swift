import UIKit

class GroupInviteCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = nameLabel.frame.origin.x
    }

}


