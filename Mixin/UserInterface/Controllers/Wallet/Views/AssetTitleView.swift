import UIKit

class AssetTitleView: UIView, XibDesignable {
    
    @IBOutlet weak var iconImageView: CornerImageView!
    @IBOutlet weak var chainImageView: CornerImageView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var usdAmountLabel: UILabel!
    @IBOutlet weak var actionButtonsStackView: UIStackView!
    @IBOutlet weak var actionButtonsSeparatorView: UIView!
    @IBOutlet weak var transferButton: UIButton!
    @IBOutlet weak var depositButton: StateResponsiveButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let height: CGFloat = actionButtonsStackView.isHidden ? 150 : 172
        return CGSize(width: size.width, height: height)
    }
    
    func render(asset: AssetItem) {
        reloadIcon(asset: asset)
        amountLabel.text = asset.balance
        symbolLabel.text = asset.symbol
        let usdBalance = asset.priceUsd.doubleValue * asset.balance.doubleValue
        if let localizedUSDBalance = CurrencyFormatter.localizedString(from: usdBalance, format: .legalTender, sign: .never) {
            usdAmountLabel.text = "≈ $" + localizedUSDBalance
        } else {
            usdAmountLabel.text = nil
        }
        depositButton.isBusy = !(asset.isAccount || asset.isAddress)
        actionButtonsStackView.isHidden = false
        actionButtonsSeparatorView.isHidden = false
    }
    
    func render(asset: AssetItem, snapshot: SnapshotItem) {
        reloadIcon(asset: asset)
        switch snapshot.type {
        case SnapshotType.deposit.rawValue, SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
        case SnapshotType.transfer.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
        default:
            break
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        symbolLabel.text = asset.symbol
        let usdAmount = snapshot.amount.doubleValue * asset.priceUsd.doubleValue
        if let value = CurrencyFormatter.localizedString(from: usdAmount, format: .legalTender, sign: .never) {
            usdAmountLabel.text = "≈ $" + value
        } else {
            usdAmountLabel.text = nil
        }
        actionButtonsStackView.isHidden = true
        actionButtonsSeparatorView.isHidden = true
    }
    
    private func reloadIcon(asset: AssetItem) {
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
        if let url = URL(string: asset.iconUrl) {
            iconImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), completed: nil)
        }
        if let chainIconUrl = asset.chainIconUrl, let url = URL(string: chainIconUrl) {
            chainImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), completed: nil)
            chainImageView.isHidden = false
        } else {
            chainImageView.isHidden = true
        }
    }
    
}
