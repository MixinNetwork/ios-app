import UIKit
import MixinServices

final class CompactAssetCell: ModernSelectedBackgroundCell {
    
    enum Style {
        case symbolWithName
        case nameWithBalance
    }
    
    @IBOutlet weak var assetIconView: BadgeIconView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var changeLabel: InsetLabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var noValueIndicator: UILabel!
    @IBOutlet weak var chainTagLabel: InsetLabel!
    @IBOutlet weak var checkmarkImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        chainTagLabel.contentInset = UIEdgeInsets(top: 1, left: 4, bottom: 1, right: 4)
        chainTagLabel.layer.cornerRadius = 4
        chainTagLabel.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        assetIconView.prepareForReuse()
    }
    
    func render(asset: AssetItem) {
        assetIconView.setIcon(asset: asset)
        nameLabel.text = asset.symbol
        descriptionLabel.text = asset.name
        if let tag = asset.chainTag {
            chainTagLabel.text = tag
            chainTagLabel.isHidden = false
        } else {
            chainTagLabel.isHidden = true
        }
        if asset.priceUsd.doubleValue > 0 {
            changeLabel.text = " \(asset.localizedUsdChange)%"
            if asset.changeUsd.doubleValue > 0 {
                changeLabel.textColor = .walletGreen
            } else {
                changeLabel.textColor = .walletRed
            }
            priceLabel.text = Currency.current.symbol + asset.localizedFiatMoneyPrice
            changeLabel.isHidden = false
            priceLabel.isHidden = false
            noValueIndicator.isHidden = true
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            priceLabel.text = nil
            changeLabel.isHidden = true
            priceLabel.isHidden = true
            noValueIndicator.isHidden = false
        }
        checkmarkImageView.isHidden = true
    }
    
    func render(token: TokenItem, style: Style) {
        assetIconView.setIcon(token: token)
        switch style {
        case .symbolWithName:
            nameLabel.text = token.symbol
            descriptionLabel.text = token.name
        case .nameWithBalance:
            nameLabel.text = token.name
            descriptionLabel.text = token.localizedBalanceWithSymbol
        }
        if let tag = token.chainTag {
            chainTagLabel.text = tag
            chainTagLabel.isHidden = false
        } else {
            chainTagLabel.isHidden = true
        }
        if token.decimalUSDPrice > 0 {
            changeLabel.text = " \(token.localizedUsdChange)%"
            if token.decimalUSDChange > 0 {
                changeLabel.textColor = .walletGreen
            } else {
                changeLabel.textColor = .walletRed
            }
            priceLabel.text = Currency.current.symbol + token.localizedFiatMoneyPrice
            changeLabel.isHidden = false
            priceLabel.isHidden = false
            noValueIndicator.isHidden = true
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            priceLabel.text = nil
            changeLabel.isHidden = true
            priceLabel.isHidden = true
            noValueIndicator.isHidden = false
        }
        checkmarkImageView.isHidden = true
    }
    
    func render(web3Token token: Web3Token) {
        assetIconView.setIcon(web3Token: token)
        nameLabel.text = token.name
        descriptionLabel.text = token.localizedBalanceWithSymbol
        chainTagLabel.isHidden = true
        if token.decimalUSDPrice > 0 {
            changeLabel.text = token.localizedPercentChange
            if token.decimalAbsoluteChange > 0 {
                changeLabel.textColor = .walletGreen
            } else {
                changeLabel.textColor = .walletRed
            }
            priceLabel.text = Currency.current.symbol + token.localizedFiatMoneyPrice
            changeLabel.isHidden = false
            priceLabel.isHidden = false
            noValueIndicator.isHidden = true
        } else {
            changeLabel.text = R.string.localizable.na() // Just for layout guidance
            priceLabel.text = nil
            changeLabel.isHidden = true
            priceLabel.isHidden = true
            noValueIndicator.isHidden = false
        }
        checkmarkImageView.isHidden = true
    }
    
    func render(token: TokenItem, isSelected: Bool) {
        assetIconView.setIcon(token: token)
        nameLabel.text = token.name
        descriptionLabel.text = token.localizedBalanceWithSymbol
        if let tag = token.chainTag {
            chainTagLabel.text = tag
            chainTagLabel.isHidden = false
        } else {
            chainTagLabel.isHidden = true
        }
        changeLabel.isHidden = true
        priceLabel.isHidden = true
        noValueIndicator.isHidden = true
        checkmarkImageView.isHidden = !isSelected
    }
    
}
