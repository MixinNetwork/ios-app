import UIKit

class GroupAddMemberCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = nameLabel.frame.origin.x
    }

}


