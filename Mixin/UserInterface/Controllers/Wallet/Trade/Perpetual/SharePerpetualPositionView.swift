import UIKit
import MixinServices

final class SharePerpetualPositionView: UIView {
    
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var operationLabel: InsetLabel!
    @IBOutlet weak var leverageLabel: InsetLabel!
    @IBOutlet weak var mascotImageView: UIImageView!
    @IBOutlet weak var entryPriceTitleLabel: UILabel!
    @IBOutlet weak var entryPriceContentLabel: UILabel!
    @IBOutlet weak var priceTitleLabel: UILabel!
    @IBOutlet weak var priceContentLabel: UILabel!
    @IBOutlet weak var obiView: ShareObiView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let layer = layer as! CAGradientLayer
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        operationLabel.contentInset = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        leverageLabel.contentInset = UIEdgeInsets(top: 4, left: 6, bottom: 2, right: 6)
        leverageLabel.font = .condensed(size: 12)
        for label: UILabel in [operationLabel, leverageLabel] {
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true
        }
        obiView.contentView.lightColors = nil
        obiView.contentView.darkColors = nil
    }
    
    func load(viewModel: PerpetualPositionViewModel, latestPrice: Decimal?) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        changeLabel.text = if let percentage = viewModel.pnlPercentage {
            PercentageFormatter.string(
                from: percentage,
                format: .pretty,
                sign: .always,
                options: .keepOneFractionDigitForZero
            )
        } else {
            "-.--%"
        }
        let layer = layer as! CAGradientLayer
        switch (AppGroupUserDefaults.User.marketColorAppearance, viewModel.pnlColor) {
        case (.greenUpRedDown, .rising), (.redUpGreenDown, .falling):
            layer.colors = [
                UIColor(displayP3RgbValue: 0x65DB8B, alpha: 1).cgColor,
                UIColor(displayP3RgbValue: 0x4ba669, alpha: 1).cgColor,
            ]
            obiView.backgroundColor = UIColor(displayP3RgbValue: 0x479e68, alpha: 1)
        case (.redUpGreenDown, .rising), (.greenUpRedDown, .falling):
            layer.colors = [
                UIColor(displayP3RgbValue: 0xFF546E, alpha: 1).cgColor,
                UIColor(displayP3RgbValue: 0xdd3e43, alpha: 1).cgColor,
            ]
            obiView.backgroundColor = UIColor(displayP3RgbValue: 0xc83b42, alpha: 1)
        }
        mascotImageView.image = switch viewModel.pnlColor {
        case .rising:
            R.image.mascot_gain()
        case .falling:
            R.image.mascot_loss()
        }
        operationLabel.text = viewModel.directionWithSymbol
        leverageLabel.text = viewModel.leverageMultiplier
        entryPriceTitleLabel.text = R.string.localizable.entry_price()
        entryPriceContentLabel.text = viewModel.entryPrice
        if let closePrice = viewModel.closePrice {
            priceTitleLabel.text = R.string.localizable.close_price()
            priceContentLabel.text = viewModel.closePrice
        } else if let latestPrice {
            priceTitleLabel.text = R.string.localizable.perps_current_price()
            priceContentLabel.text = CurrencyFormatter.localizedString(
                from: latestPrice * Currency.current.decimalRate,
                format: .fiatMoneyPrice,
                sign: .never,
                symbol: .currencySymbol
            )
        } else {
            priceTitleLabel.text = ""
            priceContentLabel.text = ""
        }
    }
    
}
