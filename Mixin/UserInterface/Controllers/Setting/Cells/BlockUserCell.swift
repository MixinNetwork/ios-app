import UIKit

class BlockUserCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_block_user"
    static let cellHeight: CGFloat = 60

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!

    func render(user: UserItem) {
        avatarImageView.setImage(with: user)
        nameLabel.text = user.fullName
    }

}

