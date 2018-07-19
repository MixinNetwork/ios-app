import UIKit

class QuotePreviewView: UIView, XibDesignable {

    @IBOutlet weak var indicatorView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var contentImageWrapperView: UIView!
    @IBOutlet weak var contentImageView: AvatarImageView!
    @IBOutlet weak var dismissButton: UIButton!
    
    private let contentImageViewNormalCornerRadius: CGFloat = 4
    
    private var isXibLoaded = false
    
    var dismissAction: (() -> Void)?
    
    @IBAction func dismissAction(_ sender: Any) {
        dismissAction?()
    }
    
    func render(message: MessageItem, contentImageThumbnail: UIImage?) {
        if !isXibLoaded {
            loadXib()
            dismissButton.imageView?.contentMode = .center
        }
        let tintColor: UIColor
        if let identityNumber = Int(message.userIdentityNumber) {
            tintColor = UIColor.usernameColors[identityNumber % UIColor.usernameColors.count]
        } else {
            tintColor = .black
        }
        indicatorView.backgroundColor = tintColor
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageView.sd_setImage(with: nil, completed: nil)
        contentImageView.titleLabel.text = nil
        contentImageView.layer.cornerRadius = contentImageViewNormalCornerRadius
        contentImageView.contentMode = .scaleAspectFill
        titleLabel.text = message.userFullName
        titleLabel.textColor = tintColor
        subtitleLabel.text = message.quoteSubtitle
        if message.category.hasSuffix("_STICKER") {
            if let assetUrl = message.assetUrl {
                contentImageView.contentMode = .scaleAspectFit
                contentImageView.sd_setImage(with: URL(string: assetUrl), completed: nil)
            }
        } else if message.category.hasSuffix("_IMAGE") {
            if let mediaUrl = message.mediaUrl, !mediaUrl.isEmpty {
                contentImageView.sd_setImage(with: MixinFile.url(ofChatDirectory: .photos, filename: mediaUrl))
            } else {
                contentImageView.image = contentImageThumbnail
            }
        } else if message.category.hasSuffix("_VIDEO") {
            contentImageView.image = contentImageThumbnail
        } else if message.category.hasSuffix("_CONTACT") {
            contentImageView.setImage(with: message.sharedUserAvatarUrl, identityNumber: message.sharedUserIdentityNumber, name: message.sharedUserFullName)
        }
        UIView.performWithoutAnimation {
            contentImageWrapperView.isHidden = (contentImageView.image == nil && contentImageView.sd_imageURL() == nil)
            iconImageView.image = MessageCategory.iconImage(forMessageCategoryString: message.category)
            iconImageView.isHidden = (iconImageView.image == nil)
        }
    }
    
}
