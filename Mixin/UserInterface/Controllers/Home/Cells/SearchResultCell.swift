import UIKit

class SearchResultCell: UITableViewCell {
    
    static let height: CGFloat = 70
    
    @IBOutlet weak var avatarImageView: AvatarShadowIconView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var badgeImageView: UIImageView!
    @IBOutlet weak var superscriptLabel: UILabel!
    @IBOutlet weak var fileIcon: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = UIView.createSelectedBackgroundView()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.iconImageView.sd_setImage(with: nil, completed: nil)
    }
    
    func render(result: SearchResult) {
        var isDataMessage = false
        switch result.target {
        case let .contact(user):
            avatarImageView.setImage(with: user.avatarUrl, userId: user.userId, name: user.fullName)
        case let .group(conversation):
            avatarImageView.setGroupImage(with: conversation.iconUrl)
        case let .searchMessageWithContact(_, userId, name):
            avatarImageView.setImage(with: result.iconUrl, userId: userId, name: name)
        case .searchMessageWithGroup:
            avatarImageView.setGroupImage(with: result.iconUrl)
        case let .message(_, _, isData, userId, userFullName, _):
            isDataMessage = isData
            avatarImageView.setImage(with: result.iconUrl, userId: userId, name: userFullName)
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
    
}
