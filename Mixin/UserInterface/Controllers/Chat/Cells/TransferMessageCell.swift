import UIKit
import MixinServices

class TransferMessageCell: CardMessageCell<UIImageView, CardMessageTitleView> {
    
    override func prepare() {
        super.prepare()
        leftView.layer.cornerRadius = TransferMessageViewModel.leftViewSideLength / 2
        leftView.clipsToBounds = true
        statusImageView.isHidden = true
        titleLabel.textColor = .text
        titleLabel.font = TransferMessageViewModel.amountFontSet.scaled
        titleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .accessoryText
        subtitleLabel.font = TransferMessageViewModel.symbolFontSet.scaled
        subtitleLabel.adjustsFontForContentSizeCategory = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        leftView.sd_cancelCurrentImageLoad()
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? TransferMessageViewModel {
            if let icon = viewModel.message.assetIcon, let url = URL(string: icon) {
                leftView.sd_setImage(with: url,
                                     placeholderImage: R.image.ic_place_holder(),
                                     context: assetIconContext)
            }
            titleLabel.text = viewModel.snapshotAmount
            subtitleLabel.text = viewModel.message.assetSymbol
        }
    }
    
}
