import UIKit

class AppCardMessageCell: CardMessageCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override var contentBottomMargin: CGFloat {
        return 36
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppCardMessageViewModel {
            iconImageView.sd_setImage(with: viewModel.message.appCard?.iconUrl)
            titleLabel.text = viewModel.message.appCard?.title
            descriptionLabel.text = viewModel.message.appCard?.description
        }
    }

}
