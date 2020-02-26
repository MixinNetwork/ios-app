import UIKit

class PostMessageCell: TextMessageCell {
    
    let expandImageView = UIImageView(image: R.image.conversation.ic_message_expand())
    let trailingInfoBackgroundView = TrailingInfoBackgroundView()
    
    override var trailingInfoColor: UIColor {
        .white
    }
    
    override func prepare() {
        contentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        contentView.addSubview(expandImageView)
        encryptedImageView.alpha = 0.9
        statusImageView.alpha = 0.9
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        let expandImageMargin: CGFloat
        if viewModel.style.contains(.received) {
            expandImageMargin = 9
        } else {
            expandImageMargin = 16
        }
        let origin = CGPoint(x: viewModel.backgroundImageFrame.maxX - expandImageView.frame.width - expandImageMargin,
                             y: viewModel.backgroundImageFrame.origin.y + 8)
        expandImageView.frame.origin = origin
        if let viewModel = viewModel as? PostMessageViewModel {
            trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
        }
    }
    
}
