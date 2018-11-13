import UIKit

class AssetTitleView: UIView, XibDesignable {
    
    @IBOutlet weak var iconImageView: CornerImageView!
    @IBOutlet weak var chainImageView: CornerImageView!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var usdBalanceLabel: UILabel!
    @IBOutlet weak var actionButtonsStackView: UIStackView!
    @IBOutlet weak var withdrawalButton: UIButton!
    @IBOutlet weak var depositButton: StateResponsiveButton!
    
    static func height(hasActionButtons: Bool) -> CGFloat {
        return hasActionButtons ? 167 : 145
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    func render(asset: AssetItem) {
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
        if let url = URL(string: asset.iconUrl) {
            iconImageView.sd_setImage(with: url, completed: nil)
        }
        if let chainIconUrl = asset.chainIconUrl, let url = URL(string: chainIconUrl) {
            iconImageView.sd_setImage(with: url, completed: nil)
        }
        balanceLabel.text = asset.balance
        symbolLabel.text = asset.symbol
        let usdBalance = asset.priceUsd.doubleValue * asset.balance.doubleValue
        if let localizedUSDBalance = CurrencyFormatter.localizedString(from: usdBalance, format: .legalTender, sign: .never) {
            usdBalanceLabel.text = "≈ $" + localizedUSDBalance
        } else {
            usdBalanceLabel.text = nil
        }
        depositButton.isBusy = !(asset.isAccount || asset.isAddress)
    }
    
}
