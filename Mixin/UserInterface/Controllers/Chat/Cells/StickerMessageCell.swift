import UIKit
import YYImage
import MixinServices

class StickerMessageCell: DetailInfoMessageCell {

    let contentImageView = YYAnimatedImageView()
    
    lazy var selectedOverlapImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.alpha = 0
        imageView.tintColor = UIColor.black.withAlphaComponent(0.2)
        contentImageView.addSubview(imageView)
        return imageView
    }()
    
    override var contentFrame: CGRect {
        return contentImageView.frame
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        contentImageView.sd_cancelCurrentImageLoad()
        contentImageView.image = nil
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? StickerMessageViewModel, let assetUrl = viewModel.message.assetUrl {
            contentImageView.frame = viewModel.contentFrame
            let context = stickerLoadContext(category: viewModel.message.assetCategory)
            contentImageView.sd_setImage(with: URL(string: assetUrl), placeholderImage: nil, context: context)
        }
    }
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        guard let overlapImage = contentImageView.image?.withRenderingMode(.alwaysTemplate) else {
            return
        }
        selectedOverlapImageView.image = overlapImage
        selectedOverlapImageView.frame = contentImageView.bounds
        UIView.animate(withDuration: animated ? highlightAnimationDuration : 0) {
            self.selectedOverlapImageView.alpha = highlight ? 1 : 0
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
