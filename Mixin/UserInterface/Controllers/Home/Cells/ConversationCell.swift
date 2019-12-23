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
    @IBOutlet weak var messageStatusImageView: UIImageView!
    @IBOutlet weak var verifiedImageView: UIImageView!
    @IBOutlet weak var pinImageView: UIImageView!
    
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
        timeLabel.text = item.createdAt.toUTCDate().timeAgo()

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
            contentLabel.text = Localized.CHAT_DECRYPTION_FAILED_HINT(username: item.senderFullName)
        } else {
            showMessageIndicate(conversation: item)
            let senderIsMe = item.senderId == myUserId
            let senderName = senderIsMe ? Localized.CHAT_MESSAGE_YOU : item.senderFullName
            
            let category = item.contentType
            messageTypeImageView.image = MessageCategory.iconImage(forMessageCategoryString: category)
            messageTypeImageView.isHidden = (messageTypeImageView.image == nil)
            if category.hasSuffix("_TEXT") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(item.content)"
                } else {
                    contentLabel.text = item.content
                }
            } else if category.hasSuffix("_IMAGE") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(Localized.NOTIFICATION_CONTENT_PHOTO)"
                } else {
                    contentLabel.text = Localized.NOTIFICATION_CONTENT_PHOTO
                }
            } else if category.hasSuffix("_STICKER") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(Localized.NOTIFICATION_CONTENT_STICKER)"
                } else {
                    contentLabel.text = Localized.NOTIFICATION_CONTENT_STICKER
                }
            } else if category.hasSuffix("_CONTACT") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(Localized.NOTIFICATION_CONTENT_CONTACT)"
                } else {
                    contentLabel.text = Localized.NOTIFICATION_CONTENT_CONTACT
                }
            } else if category.hasSuffix("_DATA") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(Localized.NOTIFICATION_CONTENT_FILE)"
                } else {
                    contentLabel.text = Localized.NOTIFICATION_CONTENT_FILE
                }
            } else if category.hasSuffix("_VIDEO") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(Localized.NOTIFICATION_CONTENT_VIDEO)"
                } else {
                    contentLabel.text = Localized.NOTIFICATION_CONTENT_VIDEO
                }
            } else if category.hasSuffix("_LIVE") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(R.string.localizable.notification_content_live())"
                } else {
                    contentLabel.text = R.string.localizable.notification_content_live()
                }
            } else if category.hasSuffix("_AUDIO") {
                if item.isGroup() {
                    contentLabel.text = "\(senderName): \(Localized.NOTIFICATION_CONTENT_AUDIO)"
                } else {
                    contentLabel.text = Localized.NOTIFICATION_CONTENT_AUDIO
                }
            } else if category.hasPrefix("WEBRTC_") {
                contentLabel.text = Localized.NOTIFICATION_CONTENT_VOICE_CALL
            } else if category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
                contentLabel.text = Localized.NOTIFICATION_CONTENT_TRANSFER
            } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue {
                contentLabel.text = (item.appButtons?.map({ (appButton) -> String in
                    return "[\(appButton.label)]"
                }) ?? []).joined()
            } else if category == MessageCategory.APP_CARD.rawValue, let appCard = item.appCard {
                contentLabel.text = "[\(appCard.title)]"
            } else if category == MessageCategory.MESSAGE_RECALL.rawValue {
                setContentLabelFontItalic(true)
                if senderIsMe {
                    contentLabel.text = R.string.localizable.chat_message_recalled_by_me()
                } else {
                    contentLabel.text = R.string.localizable.chat_message_recalled()
                }
            } else {
                if item.contentType.hasPrefix("SYSTEM_") {
                    contentLabel.text = SystemConversationAction.getSystemMessage(actionName: item.actionName, userId: item.senderId, userFullName: item.senderFullName, participantId: item.participantUserId, participantFullName: item.participantFullName, content: item.content)
                } else {
                    contentLabel.text = ""
                }
            }
        }

        if item.unseenMessageCount > 0 {
            unreadLabel.isHidden = false
            unreadLabel.text = "\(item.unseenMessageCount)"
            pinImageView.isHidden = true
            muteImageView.isHidden = true
        } else {
            unreadLabel.isHidden = true
            pinImageView.isHidden = item.pinTime == nil
            muteImageView.isHidden = !item.isMuted
        }
    }

    private func showMessageIndicate(conversation: ConversationItem) {
        if conversation.contentType.hasPrefix("WEBRTC_") || conversation.contentType == MessageCategory.MESSAGE_RECALL.rawValue {
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
            ? MessageFontSet.recalledConversationContent.scaled
            : MessageFontSet.normalConversationContent.scaled
    }
    
}
