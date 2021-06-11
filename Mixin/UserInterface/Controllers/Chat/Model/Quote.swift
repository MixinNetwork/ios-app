import UIKit
import MixinServices

struct Quote {
    
    enum Category {
        case normal
        case recalled
    }
    
    enum Image {
        case local(URL)
        case persistentSticker(URL)
        case purgableRemote(URL)
        case user(urlString: String, userId: String, name: String)
        case thumbnail(UIImage)
    }
    
    static let notFound = Quote(
        messageId: "one.mixin.messenger.not-found",
        category: .recalled,
        title: "",
        tintColor: .theme,
        icon: R.image.ic_recalled_message_prefix_received(),
        subtitle: R.string.localizable.chat_message_not_found(),
        image: nil
    )
    
    let messageId: String
    let category: Category
    let title: String
    let tintColor: UIColor
    let icon: UIImage?
    let subtitle: String
    let image: Image?
    
    init(messageId: String, category: Quote.Category, title: String, tintColor: UIColor, icon: UIImage?, subtitle: String, image: Quote.Image?) {
        self.messageId = messageId
        self.category = category
        self.title = title
        self.tintColor = tintColor
        self.icon = icon
        self.subtitle = subtitle
        self.image = image
    }
    
    init(quotedMessage message: MessageItem) {
        messageId = message.messageId
        title = message.userFullName ?? ""
        tintColor = UIColor.usernameColors[message.userId.positiveHashCode() % UIColor.usernameColors.count]
        if message.category == MessageCategory.MESSAGE_RECALL.rawValue {
            category = .recalled
            icon = R.image.ic_recalled_message_prefix_received()
            subtitle = R.string.localizable.chat_message_recalled()
            image = nil
        } else {
            category = .normal
            icon = MessageCategory.iconImage(forMessageCategoryString: message.category)
            subtitle = message.quoteSubtitle
            
            var image: Image?
            if message.mediaStatus == MediaStatus.DONE.rawValue || message.mediaStatus == MediaStatus.READ.rawValue {
                if message.category.hasSuffix("_IMAGE"), let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty {
                    let url = AttachmentContainer.url(for: .photos, filename: mediaUrl)
                    image = .local(url)
                } else if message.category.hasSuffix("_VIDEO"), let videoFilename = message.mediaUrl {
                    let url = AttachmentContainer.videoThumbnailURL(videoFilename: videoFilename)
                    image = .local(url)
                }
            } else if message.category.hasSuffix("_LIVE"), let urlString = message.thumbUrl, let url = URL(string: urlString) {
                image = .purgableRemote(url)
            } else if message.category.hasSuffix("_STICKER"), let assetUrl = message.assetUrl, let url = URL(string: assetUrl) {
                if message.assetCategory == nil {
                    image = .purgableRemote(url)
                } else {
                    image = .persistentSticker(url)
                }
            } else if message.category.hasSuffix("_CONTACT") {
                image = .user(urlString: message.sharedUserAvatarUrl ?? "",
                              userId: message.sharedUserId ?? "",
                              name: message.sharedUserFullName ?? "")
            }
            if image == nil, let thumbnail = UIImage(thumbnailString: message.thumbImage) {
                image = .thumbnail(thumbnail)
            }
            self.image = image
        }
    }
    
}

extension Quote: Equatable {
    
    static func == (lhs: Quote, rhs: Quote) -> Bool {
        lhs.messageId == rhs.messageId
    }
    
}
