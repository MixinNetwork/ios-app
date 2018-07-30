import UIKit

class FowardCell: GroupMemberSelectionCell {

    static let cellIdentifier = "cell_identifier_foward"

    override var isDisabled: Bool {
        return false
    }

    func render(user: ForwardUser) {
        if user.isGroup {
            nameLabel.text = user.name
            avatarImageView.setGroupImage(with: user.iconUrl, conversationId: user.conversationId)
            displayVerifiedIcon(isVerified: false, isBot: false)
        } else {
            nameLabel.text = user.fullName
            avatarImageView.setImage(with: user.ownerAvatarUrl, identityNumber: user.identityNumber, name: user.name)
            displayVerifiedIcon(isVerified: user.ownerIsVerified, isBot: user.isBot)
        }
    }

}
