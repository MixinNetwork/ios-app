import UIKit
import MixinServices

final class SelectedPeerCell: SelectedItemCell<AvatarImageView> {
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func render(member: CircleMember) {
        if member.category == ConversationCategory.GROUP.rawValue {
            iconView.setGroupImage(with: member.iconUrl)
        } else {
            iconView.setImage(with: member.iconUrl,
                              userId: member.userId ?? "",
                              name: member.name)
        }
        nameLabel.text = member.name
    }
    
    func render(receiver: MessageReceiver) {
        switch receiver.item {
        case .group(let conversation):
            iconView.setGroupImage(conversation: conversation)
        case .user(let user):
            iconView.setImage(with: user)
        }
        nameLabel.text = receiver.name
    }
    
    func render(item: UserItem) {
        iconView.setImage(with: item)
        nameLabel.text = item.fullName
    }
    
}
