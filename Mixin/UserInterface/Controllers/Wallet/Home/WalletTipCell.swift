import UIKit

final class WalletTipCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func walletTipCell(_ cell: WalletTipCell, requestPerformAction tip: WalletTip)
        func walletTipCell(_ cell: WalletTipCell, requestDismiss tip: WalletTip)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    weak var delegate: Delegate?
    
    var tip: WalletTip? {
        didSet {
            switch tip {
            case .addWallet:
                imageView.image = R.image.wallet_tip_add()
                titleLabel.text = R.string.localizable.wallet_home_add_wallet_banner_title()
                actionButton.configuration?.attributedTitle = AttributedString(
                    R.string.localizable.add_wallet(),
                    attributes: actionAttributes
                )
            case nil:
                imageView.image = nil
            }
        }
    }
    
    private var actionAttributes: AttributeContainer = {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14, weight: .medium)
        )
        return container
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    @IBAction func close(_ sender: Any) {
        guard let tip else {
            return
        }
        delegate?.walletTipCell(self, requestDismiss: tip)
    }
    
    @IBAction func requestAction(_ sender: Any) {
        guard let tip else {
            return
        }
        delegate?.walletTipCell(self, requestPerformAction: tip)
    }
    
}
