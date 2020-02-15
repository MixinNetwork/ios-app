import UIKit
import MixinServices

class QuotedMessageView: UIView {
    
    let backgroundImageView = UIImageView()
    let titleLabel = UILabel()
    let iconImageView = UIImageView()
    let subtitleLabel = UILabel()
    let imageView = UIImageView()
    let avatarImageView = AvatarImageView(frame: .zero)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    func prepare() {
        backgroundImageView.image = R.image.bg_chat_quote()
        addSubview(backgroundImageView)
        
        titleLabel.font = MessageFontSet.quoteTitle.scaled
        titleLabel.adjustsFontForContentSizeCategory = true
        addSubview(titleLabel)
        
        iconImageView.contentMode = .center
        addSubview(iconImageView)
        
        subtitleLabel.textColor = .accessoryText
        subtitleLabel.numberOfLines = QuotedMessageViewModel.subtitleNumberOfLines
        addSubview(subtitleLabel)
        
        imageView.layer.cornerRadius = 6
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        addSubview(avatarImageView)
    }
    
    func prepareForReuse() {
        imageView.sd_cancelCurrentImageLoad()
        imageView.image = nil
        avatarImageView.prepareForReuse()
    }
    
    func render(viewModel: QuotedMessageViewModel) {
        backgroundImageView.frame = viewModel.backgroundFrame
        titleLabel.frame = viewModel.titleFrame
        iconImageView.frame = viewModel.iconFrame
        subtitleLabel.frame = viewModel.subtitleFrame
        subtitleLabel.font = viewModel.subtitleFont
        imageView.frame = viewModel.imageFrame
        avatarImageView.frame = viewModel.imageFrame
        
        let quote = viewModel.quote
        backgroundImageView.tintColor = quote.tintColor
        titleLabel.text = quote.title
        titleLabel.textColor = quote.tintColor
        iconImageView.image = quote.icon
        subtitleLabel.text = quote.subtitle
        if let image = quote.image {
            switch image {
            case .user:
                imageView.isHidden = true
                avatarImageView.isHidden = false
            default:
                imageView.isHidden = false
                avatarImageView.isHidden = true
            }
            switch image {
            case let .local(url):
                imageView.sd_setImage(with: url, placeholderImage: nil, context: localImageContext)
            case let .purgableRemote(url):
                imageView.sd_setImage(with: url)
            case let .persistentSticker(url):
                imageView.sd_setImage(with: url, placeholderImage: nil, context: persistentStickerContext)
            case let .user(url, userId, name):
                avatarImageView.setImage(with: url, userId: userId, name: name)
            case let .thumbnail(thumbnail):
                imageView.image = thumbnail
            }
        }
    }
    
}
