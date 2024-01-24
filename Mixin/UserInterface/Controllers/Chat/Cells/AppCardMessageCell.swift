import UIKit

class AppCardMessageCell: CardMessageCell<UIImageView, CardMessageTitleView> {
    
    override func prepare() {
        super.prepare()
        leftView.layer.cornerRadius = 5
        leftView.clipsToBounds = true
        titleLabel.textColor = .text
        titleLabel.font = MessageFontSet.cardTitle.scaled
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = R.color.text_tertiary()!
        subtitleLabel.font = MessageFontSet.cardSubtitle.scaled
        subtitleLabel.adjustsFontForContentSizeCategory = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        leftView.sd_cancelCurrentImageLoad()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppCardMessageViewModel {
            leftView.sd_setImage(with: viewModel.message.appCard?.iconUrl)
            titleLabel.text = viewModel.message.appCard?.title
            subtitleLabel.text = viewModel.message.appCard?.description
        }
    }

}
