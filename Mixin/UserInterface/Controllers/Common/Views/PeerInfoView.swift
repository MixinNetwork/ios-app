import UIKit
import MixinServices

class PeerInfoView: UIView, XibDesignable {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var superscriptLabel: UILabel!
    @IBOutlet weak var prefixIconImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    private var defaultTitleFont: UIFont!
    private var defaultTitleColor: UIColor!
    private var defaultDescriptionFont: UIFont!
    private var defaultDescriptionColor: UIColor!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXibAndDefaultProperties()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXibAndDefaultProperties()
    }
    
    func prepareForReuse() {
        avatarImageView.prepareForReuse()
        titleLabel.text = nil
        titleLabel.font = defaultTitleFont
        titleLabel.textColor = defaultTitleColor
        descriptionLabel.text = nil
        descriptionLabel.font = defaultDescriptionFont
        descriptionLabel.textColor = defaultDescriptionColor
    }
    
    func render(result: SearchResult) {
        var specializedCategory: MessageSearchResult.SpecializedCategory?
        switch result {
        case let result as UserSearchResult:
            let user = result.user
            avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
        case let result as ConversationSearchResult:
            let conversation = result.conversation
            if conversation.isGroup() {
                avatarImageView.setGroupImage(with: conversation.iconUrl)
            } else {
                avatarImageView.setImage(with: conversation.ownerAvatarUrl,
                                         userId: conversation.ownerId,
                                         name: conversation.ownerFullName)
            }
        case let result as MessagesWithUserSearchResult:
            avatarImageView.setImage(with: result.iconUrl, userId: result.userId, name: result.userFullname)
        case let result as MessagesWithGroupSearchResult:
            avatarImageView.setGroupImage(with: result.iconUrl)
        case let result as MessageSearchResult:
            specializedCategory = result.specializedCategory
            avatarImageView.setImage(with: result.iconUrl, userId: result.userId, name: result.userFullname)
        case let result as MessageReceiverSearchResult:
            switch result.receiver.item {
            case .group(let conversation):
                avatarImageView.setGroupImage(with: conversation.iconUrl)
            case .user(let user):
                avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
            }
        case let result as CircleMemberSearchResult:
            let member = result.member
            if member.category == ConversationCategory.GROUP.rawValue {
                avatarImageView.setGroupImage(with: member.iconUrl)
            } else {
                avatarImageView.setImage(with: member.iconUrl, userId: member.userId ?? "", name: member.name)
            }
        default:
            break
        }
        titleLabel.attributedText = result.title
        badgeImageView.image = result.badgeImage
        badgeImageView.isHidden = badgeImageView.image == nil
        superscriptLabel.text = result.superscript
        if let category = specializedCategory {
            prefixIconImageView.isHidden = false
            switch category {
            case .data:
                prefixIconImageView.image = R.image.ic_message_file()
            case .transcript:
                prefixIconImageView.image = R.image.ic_message_transcript()
            }
        } else {
            prefixIconImageView.isHidden = true
        }
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
        badgeImageView.isHidden = badgeImageView.image == nil
        superscriptLabel.text = nil
        prefixIconImageView.isHidden = true
        descriptionLabel.isHidden = true
    }
    
    func render(user: User, userBiographyAsSubtitle: Bool) {
        avatarImageView.setImage(with: user.avatarUrl ?? "", userId: user.userId, name: user.fullName ?? "")
        titleLabel.text = user.fullName
        badgeImageView.image = SearchResult.userBadgeImage(isVerified: user.isVerified, appId: user.appId)
        badgeImageView.isHidden = badgeImageView.image == nil
        superscriptLabel.text = nil
        prefixIconImageView.isHidden = true
        if userBiographyAsSubtitle {
            descriptionLabel.isHidden = false
            descriptionLabel.text = user.biography
        } else {
            descriptionLabel.isHidden = true
        }
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
        badgeImageView.isHidden = badgeImageView.image == nil
        superscriptLabel.text = nil
        prefixIconImageView.isHidden = true
        descriptionLabel.isHidden = true
    }
    
    func render(member: CircleMember) {
        if member.category == ConversationCategory.GROUP.rawValue {
            avatarImageView.setGroupImage(with: member.iconUrl)
        } else {
            avatarImageView.setImage(with: member.iconUrl,
                                     userId: member.userId ?? "",
                                     name: member.name)
        }
        titleLabel.text = member.name
        badgeImageView.image = member.badgeImage
        badgeImageView.isHidden = badgeImageView.image == nil
        superscriptLabel.text = nil
        prefixIconImageView.isHidden = true
        descriptionLabel.isHidden = true
    }
    
    private func loadXibAndDefaultProperties() {
        loadXib()
        defaultTitleFont = titleLabel.font
        defaultTitleColor = titleLabel.textColor
        defaultDescriptionFont = descriptionLabel.font
        defaultDescriptionColor = descriptionLabel.textColor
    }
    
}
