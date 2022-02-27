import UIKit
import MixinServices

class GroupInCommonCell: UITableViewCell {
    
    @IBOutlet weak var avatarView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var groupInCommon: GroupInCommon! {
        didSet {
            avatarView.setGroupImage(with: groupInCommon.iconUrl)
            nameLabel.text = groupInCommon.name
            countLabel.text = R.string.localizable.group_title_members("\(groupInCommon.participantsCount)")
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.prepareForReuse()
    }
    
}
