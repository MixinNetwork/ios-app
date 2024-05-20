import UIKit
import MixinServices

class GroupInCommonCell: UITableViewCell {
    
    @IBOutlet weak var avatarView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    
    var groupInCommon: GroupInCommon? {
        didSet {
            guard let groupInCommon else {
                return
            }
            avatarView.setGroupImage(with: groupInCommon.iconURL ?? "")
            nameLabel.text = groupInCommon.name
            countLabel.text = R.string.localizable.title_participants_count(groupInCommon.participantsCount)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.prepareForReuse()
    }
    
}
