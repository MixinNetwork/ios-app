import UIKit

class PostMessageCell: TextMessageCell {
    
    let tagLabel = MessageTagLabel()
    let trailingInfoBackgroundView = TrailingInfoBackgroundView()
    
    override var trailingInfoColor: UIColor {
        .white
    }
    
    override func prepare() {
        contentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        tagLabel.text = R.string.localizable.chat_message_post_tag()
        tagLabel.sizeToFit()
        contentView.addSubview(tagLabel)
        encryptedImageView.alpha = 0.9
        statusImageView.alpha = 0.9
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        let tagLabelMargin: CGFloat
        if viewModel.style.contains(.received) {
            tagLabelMargin = 9
        } else {
            tagLabelMargin = 16
        }
        tagLabel.frame.origin = CGPoint(x: viewModel.backgroundImageFrame.maxX - tagLabel.frame.width - tagLabelMargin,
                                        y: viewModel.backgroundImageFrame.origin.y + 8)
        if let viewModel = viewModel as? PostMessageViewModel {
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
        }
    }
    
}
