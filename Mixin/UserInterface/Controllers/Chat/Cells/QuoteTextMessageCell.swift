import UIKit

class QuoteTextMessageCell: TextMessageCell {

    let quoteBackgroundImageView = UIImageView()
    let quoteTitleLabel = UILabel()
    let quoteIconImageView = UIImageView()
    let quoteSubtitleLabel = UILabel()
    let quoteImageView = AvatarImageView(frame: .zero)
    
    override func prepareForReuse() {
        super.prepareForReuse()
        quoteImageView.titleLabel.text = nil
        quoteImageView.sd_cancelCurrentImageLoad()
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
            if let quote = viewModel.quote {
                quoteBackgroundImageView.tintColor = quote.tintColor
                quoteTitleLabel.text = quote.title
                quoteTitleLabel.textColor = quote.tintColor
                quoteIconImageView.image = quote.icon
                quoteSubtitleLabel.text = quote.subtitle
                if let image = quote.image {
                    switch image {
                    case let .url(url):
                        quoteImageView.sd_setImage(with: url, completed: nil)
                        quoteImageView.cornerRadius = QuoteTextMessageViewModel.Quote.imageCornerRadius
                    case let .user(url, userId, name):
                        quoteImageView.setImage(with: url, userId: userId, name: name)
                        quoteImageView.cornerRadius = viewModel.quoteImageFrame.width / 2
                    case let .thumbnail(thumbnail):
                        quoteImageView.image = thumbnail
                        quoteImageView.cornerRadius = QuoteTextMessageViewModel.Quote.imageCornerRadius
                    }
                } else {
                    quoteImageView.image = nil
                }
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        
        quoteBackgroundImageView.image = #imageLiteral(resourceName: "bg_chat_quote")
        contentView.addSubview(quoteBackgroundImageView)
        
        quoteTitleLabel.font = QuoteTextMessageViewModel.Quote.titleFont
        contentView.addSubview(quoteTitleLabel)
        
        quoteIconImageView.contentMode = .center
        contentView.addSubview(quoteIconImageView)
        
        quoteSubtitleLabel.textColor = UIColor.gray
        quoteSubtitleLabel.numberOfLines = QuoteTextMessageViewModel.Quote.subtitleNumberOfLines
        contentView.addSubview(quoteSubtitleLabel)
        
        quoteImageView.clipsToBounds = true
        quoteImageView.contentMode = .scaleAspectFill
        contentView.addSubview(quoteImageView)
    }
    
}
