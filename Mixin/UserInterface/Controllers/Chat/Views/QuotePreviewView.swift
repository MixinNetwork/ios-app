import UIKit

class QuotePreviewView: UIView, XibDesignable {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var contentImageWrapperView: UIView!
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var dismissButton: UIButton!
    
    private let contentImageViewNormalCornerRadius: CGFloat = 4
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
        dismissButton.imageView?.contentMode = .center
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        dismissButton.imageView?.contentMode = .center
    }
    
    func render(message: MessageItem, contentImageThumbnail: UIImage?) {
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageView.sd_setImage(with: nil, completed: nil)
        contentImageView.layer.cornerRadius = contentImageViewNormalCornerRadius
        contentImageView.contentMode = .scaleAspectFill
        titleLabel.text = message.userFullName
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
        } else if message.category == MessageCategory.SYSTEM_ACCOUNT_SNAPSHOT.rawValue {
            if let icon = message.assetIcon {
                contentImageView.sd_setImage(with: URL(string: icon), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
            }
        }
        UIView.performWithoutAnimation {
            contentImageWrapperView.isHidden = (contentImageView.image == nil && contentImageView.sd_imageURL() == nil)
            iconImageView.image = MessageCategory.iconImage(forMessageCategoryString: message.category)
            iconImageView.isHidden = (iconImageView.image == nil)
        }
    }
    
}
