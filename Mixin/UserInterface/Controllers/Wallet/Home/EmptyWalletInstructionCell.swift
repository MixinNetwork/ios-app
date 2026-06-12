import UIKit

final class EmptyWalletInstructionCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func emptyWalletInstructionCellRequestToBuy(_ cell: EmptyWalletInstructionCell)
        func emptyWalletInstructionCellRequestToReceive(_ cell: EmptyWalletInstructionCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var buyCryptoButton: UIButton!
    @IBOutlet weak var receiveCryptoButton: UIButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.wallet_home_empty_title()
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        descriptionLabel.text = R.string.localizable.wallet_home_empty_desc()
        var attributes = AttributeContainer()
        attributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14, weight: .medium)
        )
        buyCryptoButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.wallet_home_buy_crypto(),
            attributes: attributes
        )
        receiveCryptoButton.configuration?.attributedTitle = AttributedString(
            R.string.localizable.wallet_home_receive_crypto(),
            attributes: attributes
        )
    }
    
    @IBAction func buyCrypto(_ sender: Any) {
        delegate?.emptyWalletInstructionCellRequestToBuy(self)
    }
    
    @IBAction func receiveCrypto(_ sender: Any) {
        delegate?.emptyWalletInstructionCellRequestToReceive(self)
    }
    
}
