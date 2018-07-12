import UIKit
import FLAnimatedImage

class StickerMessageCell: DetailInfoMessageCell {

    let contentImageView = FLAnimatedImageView()
    
    override var contentFrame: CGRect {
        return contentImageView.frame
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.sd_setImage(with: nil, completed: nil)
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? StickerMessageViewModel, let assetUrl = viewModel.message.assetUrl {
            contentImageView.frame = viewModel.contentFrame
            contentImageView.sd_setImage(with: URL(string: assetUrl))
        }
    }
    
    override func prepare() {
        contentView.addSubview(contentImageView)
        contentImageView.contentMode = .scaleAspectFill
        contentImageView.clipsToBounds = true
        contentImageView.layer.cornerRadius = 6
        timeLabel.textColor = .infoGray
        super.prepare()
        backgroundImageView.removeFromSuperview()
    }
    
}
