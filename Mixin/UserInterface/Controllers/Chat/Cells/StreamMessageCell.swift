import UIKit

class StreamMessageCell: TextMessageCell {
    
    let thumbnailImageView = UIImageView()
    let badgeView = LiveStreamBadgeView()
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? StreamMessageViewModel {
            thumbnailImageView.frame = viewModel.thumbnailFrame
            badgeView.frame.origin = viewModel.badgeOrigin
        }
    }
    
    override func prepare() {
        super.prepare()
        thumbnailImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.backgroundColor = .black
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(badgeView)
    }
    
}
