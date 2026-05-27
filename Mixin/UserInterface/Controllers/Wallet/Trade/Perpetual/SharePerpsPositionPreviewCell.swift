import UIKit
import MixinServices

final class SharePerpsPositionPreviewCell: UICollectionViewCell {
    
    @IBOutlet weak var positionInfoBackgroundView: GradientView!
    @IBOutlet weak var mascotImageView: UIImageView!
    
    @IBOutlet weak var changeLabel: UILabel!
    
    @IBOutlet weak var subtitleStackView: UIStackView!
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var operationLabel: InsetLabel!
    @IBOutlet weak var leverageLabel: InsetLabel!
    
    @IBOutlet weak var entryPriceTitleLabel: UILabel!
    @IBOutlet weak var entryPriceContentLabel: UILabel!
    
    @IBOutlet weak var priceTitleLabel: UILabel!
    @IBOutlet weak var priceContentLabel: UILabel!
    
    @IBOutlet weak var obiView: ShareObiView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        positionInfoBackgroundView.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        positionInfoBackgroundView.gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        changeLabel.font = .systemFont(
            ofSize: 32,
            weight: .accessiblityBoldTextCounterWeight(.bold)
        )
        subtitleStackView.setCustomSpacing(8, after: iconView)
        operationLabel.contentInset = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        leverageLabel.contentInset = UIEdgeInsets(top: 4, left: 6, bottom: 3, right: 6)
        leverageLabel.font = .condensed(size: 12)
        for label: UILabel in [operationLabel, leverageLabel] {
            label.layer.cornerRadius = 4
            label.layer.masksToBounds = true
        }
        entryPriceTitleLabel.font = .systemFont(
            ofSize: 12,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
        entryPriceContentLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.semibold)
        )
        priceTitleLabel.font = .systemFont(
            ofSize: 12,
            weight: .accessiblityBoldTextCounterWeight(.regular)
        )
        priceContentLabel.font = .systemFont(
            ofSize: 14,
            weight: .accessiblityBoldTextCounterWeight(.semibold)
        )
        obiView.contentView.lightColors = nil
        obiView.contentView.darkColors = nil
    }
    
    func load(
        dataSource: SharePerpetualPositionDataSource,
        obiContent: ShareObiView.Content,
        style: SharePerpsPositionStyle,
    ) {
        switch (AppGroupUserDefaults.User.marketColorAppearance, dataSource.color) {
        case (.greenUpRedDown, .rising), (.redUpGreenDown, .falling):
            positionInfoBackgroundView.lightColors = [
                UIColor(displayP3RgbValue: 0x65DB8B, alpha: 1),
                UIColor(displayP3RgbValue: 0x00B26E, alpha: 1),
            ]
            positionInfoBackgroundView.darkColors = positionInfoBackgroundView.lightColors
            obiView.backgroundColor = UIColor(displayP3RgbValue: 0x479e68, alpha: 1)
        case (.redUpGreenDown, .rising), (.greenUpRedDown, .falling):
            positionInfoBackgroundView.lightColors = [
                UIColor(displayP3RgbValue: 0xFF546E, alpha: 1),
                UIColor(displayP3RgbValue: 0xF22C43, alpha: 1),
            ]
            positionInfoBackgroundView.darkColors = positionInfoBackgroundView.lightColors
            obiView.backgroundColor = UIColor(displayP3RgbValue: 0xc83b42, alpha: 1)
        }
        mascotImageView.image = switch (dataSource.color, style) {
        case (.rising, .pnl):
            R.image.mascot_perps_gain_pnl()
        case (.rising, .roe):
            R.image.mascot_perps_gain_roe()!
        case (.falling, .pnl):
            R.image.mascot_perps_loss_pnl()!
        case (.falling, .roe):
            R.image.mascot_perps_loss_roe()!
        }
        changeLabel.text = switch style {
        case .pnl:
            dataSource.pnl
        case .roe:
            dataSource.roe
        }
        iconView.setIcon(tokenIconURL: dataSource.iconURL)
        operationLabel.text = dataSource.operation
        leverageLabel.text = dataSource.leverage
        entryPriceTitleLabel.text = R.string.localizable.entry_price()
        entryPriceContentLabel.text = dataSource.entryPrice
        switch dataSource.trailingPrice {
        case .closePrice(let price):
            priceTitleLabel.text = R.string.localizable.close_price()
            priceContentLabel.text = price
        case .currentPrice(let price):
            priceTitleLabel.text = R.string.localizable.perps_current_price()
            priceContentLabel.text = price
        case .none:
            priceTitleLabel.text = ""
            priceContentLabel.text = ""
        }
        obiView.load(gradient: false, content: obiContent)
    }
    
}
