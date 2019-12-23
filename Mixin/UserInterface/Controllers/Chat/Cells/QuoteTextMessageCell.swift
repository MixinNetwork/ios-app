import UIKit
import MixinServices

class QuoteTextMessageCell: TextMessageCell {
    
    let quoteBackgroundImageView = UIImageView()
    let quoteTitleLabel = UILabel()
    let quoteIconImageView = UIImageView()
    let quoteSubtitleLabel = UILabel()
    let quoteImageView = UIImageView()
    let quoteAvatarImageView = AvatarImageView(frame: .zero)
    
    override func prepareForReuse() {
        super.prepareForReuse()
        quoteImageView.sd_cancelCurrentImageLoad()
        quoteImageView.image = nil
        quoteAvatarImageView.prepareForReuse()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? QuoteTextMessageViewModel {
            quoteBackgroundImageView.frame = viewModel.quoteBackgroundFrame
            quoteTitleLabel.frame = viewModel.quoteTitleFrame
            quoteIconImageView.frame = viewModel.quoteIconFrame
            quoteSubtitleLabel.frame = viewModel.quoteSubtitleFrame
            quoteSubtitleLabel.font = viewModel.subtitleFont
            quoteImageView.frame = viewModel.quoteImageFrame
            quoteAvatarImageView.frame = viewModel.quoteImageFrame
            if let quote = viewModel.quote {
                quoteBackgroundImageView.tintColor = quote.tintColor
                quoteTitleLabel.text = quote.title
                quoteTitleLabel.textColor = quote.tintColor
                quoteIconImageView.image = quote.icon
                quoteSubtitleLabel.text = quote.subtitle
                if let image = quote.image {
                    switch image {
                    case .user:
                        quoteImageView.isHidden = true
                        quoteAvatarImageView.isHidden = false
                    default:
                        quoteImageView.isHidden = false
                        quoteAvatarImageView.isHidden = true
                    }
                    switch image {
                    case let .local(url):
                        quoteImageView.sd_setImage(with: url, placeholderImage: nil, context: localImageContext)
                    case let .purgableRemote(url):
                        quoteImageView.sd_setImage(with: url)
                    case let .persistentSticker(url):
                        quoteImageView.sd_setImage(with: url, placeholderImage: nil, context: persistentStickerContext)
                    case let .user(url, userId, name):
                        quoteAvatarImageView.setImage(with: url, userId: userId, name: name)
                    case let .thumbnail(thumbnail):
                        quoteImageView.image = thumbnail
                    }
                }
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        
        quoteBackgroundImageView.image = R.image.bg_chat_quote()
        contentView.addSubview(quoteBackgroundImageView)
        
        quoteTitleLabel.font = MessageFontSet.quoteTitle.scaled
        quoteTitleLabel.adjustsFontForContentSizeCategory = true
        contentView.addSubview(quoteTitleLabel)
        
        quoteIconImageView.contentMode = .center
        contentView.addSubview(quoteIconImageView)
        
        quoteSubtitleLabel.textColor = .accessoryText
        quoteSubtitleLabel.numberOfLines = QuoteTextMessageViewModel.Quote.subtitleNumberOfLines
        contentView.addSubview(quoteSubtitleLabel)
        
        quoteImageView.layer.cornerRadius = QuoteTextMessageViewModel.Quote.imageCornerRadius
        quoteImageView.clipsToBounds = true
        quoteImageView.contentMode = .scaleAspectFill
        contentView.addSubview(quoteImageView)
        contentView.addSubview(quoteAvatarImageView)
    }
    
}
