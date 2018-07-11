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
        quoteImageView.sd_setImage(with: nil, completed: nil)
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? QuoteTextMessageViewModel {
            quoteBackgroundImageView.frame = viewModel.quoteBackgroundFrame
            quoteTitleLabel.frame = viewModel.quoteTitleFrame
            quoteIconImageView.frame = viewModel.quoteIconFrame
            quoteSubtitleLabel.frame = viewModel.quoteSubtitleFrame
            quoteImageView.frame = viewModel.quoteImageFrame
            if let quote = viewModel.quote {
                quoteTitleLabel.text = quote.title
                quoteTitleLabel.textColor = quote.titleColor
                quoteIconImageView.image = quote.icon
                quoteSubtitleLabel.text = quote.subtitle
                if let image = quote.image {
                    switch image {
                    case let .url(url, contentMode):
                        quoteImageView.contentMode = contentMode
                        quoteImageView.sd_setImage(with: url, completed: nil)
                        quoteImageView.cornerRadius = QuoteTextMessageViewModel.Quote.imageCornerRadius
                    case let .user(url, identityNumber, name):
                        quoteImageView.contentMode = .scaleToFill
                        quoteImageView.setImage(with: url, identityNumber: identityNumber, name: name)
                        quoteImageView.cornerRadius = viewModel.quoteImageFrame.width / 2
                    case let .thumbnail(thumbnail):
                        quoteImageView.contentMode = .scaleAspectFill
                        quoteImageView.image = thumbnail
                        quoteImageView.cornerRadius = QuoteTextMessageViewModel.Quote.imageCornerRadius
                    }
                }
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        
        quoteBackgroundImageView.image = #imageLiteral(resourceName: "bg_chat_quote")
        addSubview(quoteBackgroundImageView)
        
        quoteTitleLabel.font = QuoteTextMessageViewModel.Quote.titleFont
        addSubview(quoteTitleLabel)
        
        quoteIconImageView.contentMode = .center
        addSubview(quoteIconImageView)
        
        quoteSubtitleLabel.font = QuoteTextMessageViewModel.Quote.subtitleFont
        quoteSubtitleLabel.textColor = UIColor.gray
        addSubview(quoteSubtitleLabel)
        
        quoteImageView.clipsToBounds = true
        addSubview(quoteImageView)
    }
    
}
