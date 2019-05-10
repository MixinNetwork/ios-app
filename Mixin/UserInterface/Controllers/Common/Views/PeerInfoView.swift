import UIKit

class PeerInfoView: UIView, XibDesignable {
    
    @IBOutlet weak var avatarImageView: AvatarShadowIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var superscriptLabel: UILabel!
    @IBOutlet weak var fileIcon: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    func prepareForReuse() {
        avatarImageView.iconImageView.sd_setImage(with: nil, completed: nil)
    }
    
    func render(result: SearchResult) {
        var isDataMessage = false
        switch result.target {
        case let .contact(user):
            avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
        case let .conversation(conversation):
            if conversation.isGroup() {
                avatarImageView.setGroupImage(with: conversation.iconUrl)
            } else {
                avatarImageView.setImage(with: conversation.ownerAvatarUrl,
                                         userId: conversation.ownerId,
                                         name: conversation.ownerFullName)
            }
        case let .searchMessageWithContact(_, userId, name):
            avatarImageView.setImage(with: result.iconUrl, userId: userId, name: name)
        case .searchMessageWithGroup:
            avatarImageView.setGroupImage(with: result.iconUrl)
        case let .message(_, _, isData, userId, userFullName, _):
            isDataMessage = isData
            avatarImageView.setImage(with: result.iconUrl, userId: userId, name: userFullName)
        case let .messageReceiver(receiver):
            switch receiver.item {
            case .group(let conversation):
                avatarImageView.setGroupImage(with: conversation.iconUrl)
            case .user(let user):
                avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
            }
        }
        titleLabel.attributedText = result.title
        if let badge = result.badgeImage {
            badgeImageView.image = badge
            badgeImageView.isHidden = false
        } else {
            badgeImageView.isHidden = true
        }
        superscriptLabel.text = result.superscript
        fileIcon.isHidden = !isDataMessage
        if let description = result.description {
            descriptionLabel.attributedText = description
            descriptionLabel.isHidden = false
        } else {
            descriptionLabel.isHidden = true
        }
    }
    
    func render(user: UserItem) {
        avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
        titleLabel.text = user.fullName
        badgeImageView.image = SearchResult.userBadgeImage(isVerified: user.isVerified, appId: user.appId)
        superscriptLabel.text = nil
        fileIcon.isHidden = true
        descriptionLabel.isHidden = true
    }
    
    func render(receiver: MessageReceiver) {
        switch receiver.item {
        case let .group(conversation):
            avatarImageView.setGroupImage(with: conversation.iconUrl)
        case let .user(user):
            avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
        }
        titleLabel.text = receiver.name
        badgeImageView.image = receiver.badgeImage
        superscriptLabel.text = nil
        fileIcon.isHidden = true
        descriptionLabel.isHidden = true
    }
    
}
