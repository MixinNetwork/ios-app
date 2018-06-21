import UIKit

struct Quote {
    
    static let jsonDecoder = JSONDecoder()

    let title: String
    let icon: UIImage?
    let subtitle: String
    let thumbnail: UIImage?
    let imageUrl: URL?
    let imageContentMode: UIViewContentMode
    
    init?(quoteContent: Data) {
        guard let message = try? Quote.jsonDecoder.decode(MessageItem.self, from: quoteContent) else {
            return nil
        }
        title = message.userFullName
        icon = MessageCategory.iconImage(forMessageCategoryString: message.category)
        subtitle = message.quoteSubtitle

        var thumbnail: UIImage?
        if let thumbnailString = message.thumbImage, let data = Data(base64Encoded: thumbnailString) {
            thumbnail = UIImage(data: data)
        } else {
            thumbnail = nil
        }
        self.thumbnail = thumbnail
        
        var imageUrl: URL?
        var imageContentMode = UIViewContentMode.scaleAspectFill
        if message.mediaStatus == MediaStatus.DONE.rawValue {
            if message.category.hasSuffix("_IMAGE"), let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty {
                imageUrl = MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl)
            } else if message.category.hasSuffix("_VIDEO"), let mediaUrl = message.mediaUrl, let filename = mediaUrl.components(separatedBy: ".").first {
                let betterThumbnailFilename = filename + ExtensionName.jpeg.withDot
                imageUrl = MixinFile.url(ofChatDirectory: .videos, filename: betterThumbnailFilename)
            } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue, let assetIcon = message.assetIcon {
                imageUrl = URL(string: assetIcon)
            }
        } else if message.category.hasSuffix("_STICKER"), let assetUrl = message.assetUrl {
            imageContentMode = .scaleAspectFit
            imageUrl = URL(string: assetUrl)
        }
        self.imageUrl = imageUrl
        self.imageContentMode = imageContentMode
    }
    
}
