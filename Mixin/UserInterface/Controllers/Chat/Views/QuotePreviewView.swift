import UIKit
import MixinServices

class QuotePreviewView: UIView, XibDesignable {
    
    @IBOutlet weak var indicatorView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var contentImageWrapperView: UIView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var dismissButton: UIButton!
    
    private var isXibLoaded = false
    
    var dismissAction: (() -> Void)?
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissAction?()
    }
    
    func render(message: MessageItem, contentImageThumbnail: UIImage?) {
        if !isXibLoaded {
            loadXib()
            isXibLoaded = true
            dismissButton.imageView?.contentMode = .center
        }
        avatarImageView.prepareForReuse()
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
        let tintColor = UIColor.usernameColors[message.userId.positiveHashCode() % UIColor.usernameColors.count]
        indicatorView.backgroundColor = tintColor
        titleLabel.text = message.userFullName
        titleLabel.textColor = tintColor
        subtitleLabel.text = message.quoteSubtitle
        
        if message.category.hasSuffix("_CONTACT") {
            contentImageWrapperView.isHidden = false
            avatarImageView.isHidden = false
            imageView.isHidden = true
        } else if ["_STICKER", "_IMAGE", "_VIDEO", "_LIVE"].contains(where: message.category.hasSuffix) {
            contentImageWrapperView.isHidden = false
            avatarImageView.isHidden = true
            imageView.isHidden = false
            if message.category.hasSuffix("_STICKER") || message.category.hasSuffix("_LIVE") {
                imageView.contentMode = .scaleAspectFit
            } else {
                imageView.contentMode = .scaleAspectFill
            }
        } else {
            contentImageWrapperView.isHidden = true
        }
        
        if message.category.hasSuffix("_STICKER") {
            if let assetUrl = message.assetUrl {
                let url = URL(string: assetUrl)
                let context = stickerLoadContext(stickerId: message.stickerId)
                imageView.sd_setImage(with: url, placeholderImage: contentImageThumbnail, context: context)
            }
        } else if message.category.hasSuffix("_IMAGE") {
            if let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty {
                let url = AttachmentContainer.url(for: .photos, filename: mediaUrl)
                imageView.sd_setImage(with: url, placeholderImage: contentImageThumbnail, context: localImageContext)
            } else {
                imageView.image = contentImageThumbnail
            }
        } else if message.category.hasSuffix("_VIDEO") {
            imageView.image = contentImageThumbnail
        } else if message.category.hasSuffix("_LIVE") {
            if let thumbUrl = message.thumbUrl {
                imageView.sd_setImage(with: URL(string: thumbUrl))
            }
        } else if message.category.hasSuffix("_CONTACT") {
            avatarImageView.setImage(with: message.sharedUserAvatarUrl ?? "",
                                     userId: message.sharedUserId ?? "",
                                     name: message.sharedUserFullName ?? "")
        }
        UIView.performWithoutAnimation {
            iconImageView.image = MessageCategory.iconImage(forMessageCategoryString: message.category)
            iconImageView.isHidden = (iconImageView.image == nil)
        }
    }
    
}
