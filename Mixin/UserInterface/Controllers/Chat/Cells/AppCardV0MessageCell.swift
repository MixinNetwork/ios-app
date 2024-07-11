import UIKit
import MixinServices

final class AppCardV0MessageCell: CardMessageCell<UIImageView, CardMessageTitleView> {
    
    var content: AppCardData.V0Content?
    
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
        leftView.sd_setImage(with: content?.iconUrl)
        titleLabel.text = content?.title
        subtitleLabel.text = content?.description
    }
    
}
