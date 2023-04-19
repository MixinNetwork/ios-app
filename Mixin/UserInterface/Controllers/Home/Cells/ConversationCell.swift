import UIKit
import SDWebImage
import MixinServices

class ConversationCell: ModernSelectedBackgroundCell {
    
    @IBOutlet weak var avatarView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var muteImageView: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var messageTypeImageView: UIImageView!
    @IBOutlet weak var unreadLabel: InsetLabel!
    @IBOutlet weak var mentionLabel: InsetLabel!
    @IBOutlet weak var messageStatusImageView: UIImageView!
    @IBOutlet weak var verifiedImageView: UIImageView!
    @IBOutlet weak var pinImageView: UIImageView!
    @IBOutlet weak var expiredImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        unreadLabel.contentInset = UIEdgeInsets(top: 1, left: 5, bottom: 2, right: 5)
        mentionLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 2, right: 0)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.prepareForReuse()
        setContentLabelFontItalic(false)
    }
    
    func render(item: ConversationItem) {
        if item.category == ConversationCategory.CONTACT.rawValue {
            avatarView.setImage(with: item.ownerAvatarUrl, userId: item.ownerId, name: item.ownerFullName)
        } else {
            avatarView.setGroupImage(with: item.iconUrl)
        }
        nameLabel.text = item.getConversationName()
        if item.createdAt.isEmpty {
            timeLabel.text = ""
        } else {
            timeLabel.text = item.createdAt.toUTCDate().timeAgo()
        }

        if item.ownerIsVerified {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_verified")
            verifiedImageView.isHidden = false
        } else if item.ownerIsBot {
            verifiedImageView.image = #imageLiteral(resourceName: "ic_user_bot")
            verifiedImageView.isHidden = false
        } else {
            verifiedImageView.isHidden = true
        }

        if item.messageStatus == MessageStatus.FAILED.rawValue {
            messageStatusImageView.isHidden = false
            messageStatusImageView.image = #imageLiteral(resourceName: "ic_status_sending")
            messageTypeImageView.isHidden = true
        } else if item.messageStatus == MessageStatus.UNKNOWN.rawValue {
            messageStatusImageView.isHidden = true
            messageTypeImageView.isHidden = true
        } else {
            expiredImageView.isHidden = item.contentExpireIn == 0 || item.contentType.hasPrefix("SYSTEM_")
            showMessageIndicate(conversation: item)
            let category = item.contentType
            messageTypeImageView.image = MessageCategory.iconImage(forMessageCategoryString: category)
            messageTypeImageView.isHidden = (messageTypeImageView.image == nil)
            if category == MessageCategory.MESSAGE_RECALL.rawValue {
                setContentLabelFontItalic(true)
            }
        }
        contentLabel.text = item.displayContent
        
        let hasUnreadMessage = item.unseenMessageCount > 0
        let hasUnreadMention = item.unseenMentionCount > 0
        if hasUnreadMessage || hasUnreadMessage {
            pinImageView.isHidden = true
            muteImageView.isHidden = true
        } else {
            pinImageView.isHidden = item.pinTime == nil
            muteImageView.isHidden = !item.isMuted
        }
        if hasUnreadMessage {
            if item.isMuted {
                unreadLabel.textColor = .chatUnreadMute
                unreadLabel.backgroundColor = .textAccessory
            } else {
                unreadLabel.textColor = .white
                unreadLabel.backgroundColor = .theme
            }
            unreadLabel.isHidden = false
            unreadLabel.alpha = 1
            unreadLabel.text = "\(item.unseenMessageCount)"
        } else {
            unreadLabel.isHidden = true
            // XXX: Sometimes unread label shows for no reason, even if `isHidden` is alreay `true`
            unreadLabel.alpha = 0
            unreadLabel.text = nil
        }
        mentionLabel.isHidden = !hasUnreadMention
    }

    private func showMessageIndicate(conversation: ConversationItem) {
        let hideStatus = ["WEBRTC_", "KRAKEN_"].contains(where: conversation.contentType.hasPrefix(_:))
            || conversation.contentType == MessageCategory.MESSAGE_RECALL.rawValue
        if hideStatus {
            messageStatusImageView.isHidden = true
        } else if conversation.senderId == myUserId, !conversation.contentType.hasPrefix("SYSTEM_") {
            messageStatusImageView.isHidden = false
            switch conversation.messageStatus {
            case MessageStatus.SENDING.rawValue:
                messageStatusImageView.image = #imageLiteral(resourceName: "ic_status_sending")
            case MessageStatus.SENT.rawValue:
                messageStatusImageView.image = #imageLiteral(resourceName: "ic_status_sent")
            case MessageStatus.DELIVERED.rawValue:
                messageStatusImageView.image = #imageLiteral(resourceName: "ic_status_delivered")
            case MessageStatus.READ.rawValue:
                messageStatusImageView.image = #imageLiteral(resourceName: "ic_status_read")
            default:
                messageStatusImageView.isHidden = true
            }
        } else {
            messageStatusImageView.isHidden = true
        }
    }
    
    private func setContentLabelFontItalic(_ isItalic: Bool) {
        contentLabel.font = isItalic
            ? ConversationFontSet.recalledContent.scaled
            : ConversationFontSet.normalContent.scaled
    }
    
}
