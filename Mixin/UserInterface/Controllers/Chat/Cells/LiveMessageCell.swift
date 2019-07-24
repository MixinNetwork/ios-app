import UIKit

class LiveMessageCell: PhotoRepresentableMessageCell {
    
    let badgeView = UIImageView(image: R.image.live_badge())
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? LiveMessageViewModel {
            badgeView.frame.origin = viewModel.badgeOrigin
            if let urlString = viewModel.message.thumbUrl, let url = URL(string: urlString) {
                contentImageView.setImage(with: url, placeholder: nil, ratio: viewModel.aspectRatio)
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        contentImageView.backgroundColor = .black
        contentView.addSubview(badgeView)
    }
    
}
