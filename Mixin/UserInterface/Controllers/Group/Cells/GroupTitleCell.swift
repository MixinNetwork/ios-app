import UIKit

class GroupTitleCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var editButton: StateResponsiveButton!
    @IBOutlet weak var placeView: UIView!

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset.left = nameLabel.frame.origin.x
    }
    
    func render(conversation: ConversationItem) {
        avatarImageView.setGroupImage(with: conversation.iconUrl, conversationId: conversation.conversationId)
        nameLabel.text = conversation.name
    }
    
}

