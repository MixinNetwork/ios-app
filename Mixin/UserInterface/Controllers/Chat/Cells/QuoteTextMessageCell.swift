import UIKit

class QuoteTextMessageCell: TextMessageCell {

    let quoteBackgroundImageView = UIImageView()
    let quoteTitleLabel = UILabel()
    let quoteIconImageView = UIImageView()
    let quoteSubtitleLabel = UILabel()
    let quoteImageView = UIImageView()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        quoteImageView.sd_cancelCurrentImageLoad()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? QuoteTextMessageViewModel {
            quoteBackgroundImageView.frame = viewModel.quoteBackgroundFrame
            quoteTitleLabel.text = viewModel.quote?.title
            quoteTitleLabel.frame = viewModel.quoteTitleFrame
            quoteIconImageView.image = viewModel.quote?.icon
            quoteIconImageView.frame = viewModel.quoteIconFrame
            quoteSubtitleLabel.text = viewModel.quote?.subtitle
            quoteSubtitleLabel.frame = viewModel.quoteSubtitleFrame
            quoteImageView.frame = viewModel.quoteImageFrame
            quoteImageView.contentMode = viewModel.quote?.imageContentMode ?? .scaleAspectFit
            if let url = viewModel.quote?.imageUrl {
                quoteImageView.sd_setImage(with: url, completed: nil)
            } else {
                quoteImageView.image = viewModel.quote?.thumbnail
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
        
        quoteImageView.layer.cornerRadius = 6
        quoteImageView.clipsToBounds = true
        addSubview(quoteImageView)
    }
    
}
