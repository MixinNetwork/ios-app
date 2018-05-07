import UIKit

class WalletAssetCell: UITableViewCell {

    static let cellIdentifier = "cell_identifier_asset"
    static let cellHeight: CGFloat = 70

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var balanceLabel: UILabel!
    @IBOutlet weak var exchangeLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var blockchainImageView: CornerImageView!

    private lazy var redLabelAttribute: [NSAttributedStringKey: Any] = {
        return [.font: priceChangeLabel.font,
                .foregroundColor: UIColor(rgbValue: 0xEE7474)]
    }()
    private lazy var greenLabelAttribute: [NSAttributedStringKey: Any] = {
        return [.font: priceChangeLabel.font,
                .foregroundColor: UIColor(rgbValue: 0x66AA77)]
    }()
    private lazy var labelAttribute: [NSAttributedStringKey: Any] = {
        return [.font: priceChangeLabel.font,
                .foregroundColor: priceChangeLabel.textColor]
    }()

    func render(asset: AssetItem) {
        nameLabel.text = asset.name
        balanceLabel.text = String(format: "%@ %@", asset.balance.formatBalance(), asset.symbol)
        exchangeLabel.text = asset.getUSDBalance()
        iconImageView.sd_setImage(with: URL(string: asset.iconUrl), placeholderImage: #imageLiteral(resourceName: "ic_place_holder"))
        if let chainIconUrl = asset.chainIconUrl {
            blockchainImageView.sd_setImage(with: URL(string: chainIconUrl))
            blockchainImageView.isHidden = false
        } else {
            blockchainImageView.isHidden = true
        }

        let changeContent = NSMutableAttributedString()
        if asset.priceUsd.toDouble() > 0 {
            changeContent.append(NSAttributedString(string: "$\(asset.priceUsd) ", attributes: labelAttribute))
            if asset.changeUsd.toDouble() > 0 {
                 changeContent.append(NSAttributedString(string: "\(asset.getUsdChange())%", attributes: greenLabelAttribute))
            } else {
                changeContent.append(NSAttributedString(string: "\(asset.getUsdChange())%", attributes: redLabelAttribute))
            }
        } else {
            changeContent.append(NSAttributedString(string: Localized.WALLET_NO_PRICE, attributes: labelAttribute))
        }
        priceChangeLabel.attributedText = changeContent
    }

}
