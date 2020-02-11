import UIKit
import MixinServices

class TransferMessageCell: CardMessageCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    
    let amountLabel = UILabel()
    let symbolLabel = UILabel()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        statusImageView.isHidden = true
        amountLabel.textColor = .text
        amountLabel.font = TransferMessageViewModel.amountFont
        amountLabel.adjustsFontForContentSizeCategory = true
        symbolLabel.textColor = .accessoryText
        symbolLabel.font = TransferMessageViewModel.symbolFont
        symbolLabel.adjustsFontForContentSizeCategory = true
        rightView.addSubview(amountLabel)
        rightView.addSubview(symbolLabel)
        amountLabel.snp.makeConstraints { (make) in
            make.leading.trailing.top.equalToSuperview()
        }
        symbolLabel.snp.makeConstraints { (make) in
            make.top.equalTo(amountLabel.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
        }
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
