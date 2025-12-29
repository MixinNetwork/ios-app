import UIKit
import MixinServices

final class WalletSummaryValueCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func walletSummaryValueCellRequestTip(_ cell: WalletSummaryValueCell)
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var infoButton: UIButton!
    @IBOutlet weak var valueLabel: UILabel!
    
    @IBOutlet weak var assetChartView: BarChartView!
    
    @IBOutlet weak var leftAssetWrapperView: UIView!
    @IBOutlet weak var leftAssetSampleImageView: UIImageView!
    @IBOutlet weak var leftAssetSymbolLabel: UILabel!
    @IBOutlet weak var leftAssetPercentLabel: UILabel!
    
    @IBOutlet weak var middleAssetWrapperView: UIView!
    @IBOutlet weak var middleAssetSymbolLabel: UILabel!
    @IBOutlet weak var middleAssetPercentLabel: UILabel!
    
    @IBOutlet weak var rightAssetWrapperView: UIView!
    @IBOutlet weak var rightAssetSymbolLabel: UILabel!
    @IBOutlet weak var rightAssetPercentLabel: UILabel!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        titleLabel.text = R.string.localizable.total_balance()
    }
    
    @IBAction func requestTip(_ sender: Any) {
        delegate?.walletSummaryValueCellRequestTip(self)
    }
    
    func load(summary: WalletSummary) {
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: summary.usdValue,
            fontSize: 30
        )
        let components = summary.components
        assetChartView.proportions = components.map { component in
            NSDecimalNumber(decimal: component.percentage).doubleValue
        }
        switch components.count {
        case 0:
            leftAssetSampleImageView.image = R.image.wallet.token_sample_none()
            leftAssetSymbolLabel.text = nil
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: 0)
            middleAssetWrapperView.alpha = 0
            rightAssetWrapperView.alpha = 0
        case 1:
            leftAssetSampleImageView.image = R.image.wallet.token_sample_primary()
            leftAssetSymbolLabel.text = components[0].symbol.localized
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: 1)
            middleAssetWrapperView.alpha = 0
            rightAssetWrapperView.alpha = 0
        case 2:
            leftAssetSampleImageView.image = R.image.wallet.token_sample_primary()
            leftAssetSymbolLabel.text = components[0].symbol.localized
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: components[0].percentage)
            middleAssetWrapperView.alpha = 1
            middleAssetSymbolLabel.text = components[1].symbol.localized
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: components[1].percentage)
            rightAssetWrapperView.alpha = 0
        default:
            leftAssetSampleImageView.image = R.image.wallet.token_sample_primary()
            leftAssetSymbolLabel.text = components[0].symbol.localized
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: components[0].percentage)
            middleAssetWrapperView.alpha = 1
            middleAssetSymbolLabel.text = components[1].symbol.localized
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: components[1].percentage)
            rightAssetWrapperView.alpha = 1
            rightAssetSymbolLabel.text = components[2].symbol.localized
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: components[2].percentage)
        }
    }
    
}
