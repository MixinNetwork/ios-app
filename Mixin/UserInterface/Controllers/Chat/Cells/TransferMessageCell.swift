import UIKit
import MixinServices

class TransferMessageCell: CardMessageCell {

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        statusImageView.isHidden = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.sd_cancelCurrentImageLoad()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? TransferMessageViewModel {
            if let icon = viewModel.message.assetIcon {
                let url = URL(string: icon)
                iconImageView.sd_setImage(with: url, placeholderImage: R.image.ic_place_holder(), context: assetIconContext)
            }
            amountLabel.text = viewModel.snapshotAmount
            symbolLabel.text = viewModel.message.assetSymbol
        }
    }

}
