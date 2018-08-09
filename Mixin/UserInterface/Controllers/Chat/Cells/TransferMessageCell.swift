import UIKit

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
                iconImageView.sd_setImage(with: URL(string: icon), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
            }
            amountLabel.text = viewModel.snapshotAmount
            symbolLabel.text = viewModel.message.assetSymbol
        }
    }

}
