import UIKit

class BlockUserCell: UITableViewCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
    func render(user: UserItem) {
        avatarImageView.setImage(with: user)
        nameLabel.text = user.fullName
    }
    
}
