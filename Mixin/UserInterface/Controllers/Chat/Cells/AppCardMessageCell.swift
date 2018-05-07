import UIKit

class AppCardMessageCell: CardMessageCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override var contentTopMargin: CGFloat {
        return 11
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        timeLabel.isHidden = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppCardMessageViewModel {
            iconImageView.sd_setImage(with: viewModel.message.appCard?.icon, completed: nil)
            titleLabel.text = viewModel.message.appCard?.title
            descriptionLabel.text = viewModel.message.appCard?.description
        }
    }

}
