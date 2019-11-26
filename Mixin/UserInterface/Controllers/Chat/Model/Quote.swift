import UIKit

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
    
    let category: Category
    let title: String
    let tintColor: UIColor
    let icon: UIImage?
    let subtitle: String
    let image: Image?
    
    init?(quoteContent: Data) {
        guard let message = try? JSONDecoder.default.decode(MessageItem.self, from: quoteContent) else {
            assertionFailure("Quote content decoding failed")
            return nil
        }
        title = message.userFullName
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
                    let url = MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
                    image = .local(url)
                } else if message.category.hasSuffix("_VIDEO"), let mediaUrl = message.mediaUrl, let filename = mediaUrl.components(separatedBy: ".").first {
                    let betterThumbnailFilename = filename + ExtensionName.jpeg.withDot
                    let url = MixinFile.url(ofChatDirectory: .videos, filename: betterThumbnailFilename)
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
                image = .user(urlString: message.sharedUserAvatarUrl, userId: message.sharedUserId ?? "", name: message.sharedUserFullName)
            }
            if image == nil, let thumbString = message.thumbImage, let data = Data(base64Encoded: thumbString), let thumbnail = UIImage(data: data) {
                image = .thumbnail(thumbnail)
            }
            self.image = image
        }
    }
    
}
