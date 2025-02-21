import UIKit
import MixinServices

final class WalletSummaryValueCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        titleLabel.text = R.string.localizable.total_assets()
    }
    
    func load(digest: WalletDigest) {
        // TODO: Make sure percents sum is 100%
        valueLabel.attributedText = FiatMoneyValueAttributedStringBuilder.attributedString(
            usdValue: digest.usdBalanceSum,
            fontSize: 30
        )
        let tokens = digest.tokens
        switch tokens.count {
        case 0:
            assetChartView.proportions = []
            leftAssetSampleImageView.image = R.image.wallet.token_sample_none()
            leftAssetSymbolLabel.text = nil
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: 0)
            middleAssetWrapperView.alpha = 0
            rightAssetWrapperView.alpha = 0
        case 1:
            assetChartView.proportions = [1]
            leftAssetSampleImageView.image = R.image.wallet.token_sample_primary()
            leftAssetSymbolLabel.text = tokens[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: 1)
            middleAssetWrapperView.alpha = 0
            rightAssetWrapperView.alpha = 0
        case 2:
            let totalValue = tokens.map(\.decimalValue).reduce(0, +)
            let firstProportion = tokens[0].decimalValue / totalValue
            let secondProportion = 1 - firstProportion
            assetChartView.proportions = [
                NSDecimalNumber(decimal: firstProportion).doubleValue,
                NSDecimalNumber(decimal: secondProportion).doubleValue,
            ]
            leftAssetSymbolLabel.text = tokens[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: firstProportion)
            middleAssetWrapperView.alpha = 1
            middleAssetSymbolLabel.text = tokens[1].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: secondProportion)
            rightAssetWrapperView.alpha = 0
        case 3:
            let totalValue = tokens.map(\.decimalValue).reduce(0, +)
            let firstProportion = tokens[0].decimalValue / totalValue
            let secondProportion = tokens[1].decimalValue / totalValue
            let thirdProportion = 1 - firstProportion - secondProportion
            assetChartView.proportions = [
                NSDecimalNumber(decimal: firstProportion).doubleValue,
                NSDecimalNumber(decimal: secondProportion).doubleValue,
                NSDecimalNumber(decimal: thirdProportion).doubleValue,
            ]
            leftAssetSymbolLabel.text = tokens[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: firstProportion)
            middleAssetWrapperView.alpha = 1
            middleAssetSymbolLabel.text = tokens[1].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: secondProportion)
            rightAssetWrapperView.alpha = 1
            rightAssetSymbolLabel.text = tokens[2].symbol
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: thirdProportion)
        default:
            let totalValue = digest.usdBalanceSum
            let firstProportion = tokens[0].decimalValue / totalValue
            let secondProportion = tokens[1].decimalValue / totalValue
            let thirdProportion = 1 - firstProportion - secondProportion
            assetChartView.proportions = [
                NSDecimalNumber(decimal: firstProportion).doubleValue,
                NSDecimalNumber(decimal: secondProportion).doubleValue,
                NSDecimalNumber(decimal: thirdProportion).doubleValue,
            ]
            leftAssetSymbolLabel.text = tokens[0].symbol
            leftAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: firstProportion)
            middleAssetWrapperView.alpha = 1
            middleAssetSymbolLabel.text = tokens[1].symbol
            middleAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: secondProportion)
            rightAssetWrapperView.alpha = 1
            rightAssetSymbolLabel.text = R.string.localizable.other().uppercased()
            rightAssetPercentLabel.text = NumberFormatter.simplePercentage.string(decimal: thirdProportion)
        }
    }
    
}
