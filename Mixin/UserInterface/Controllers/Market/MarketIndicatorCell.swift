import UIKit

final class MarketIndicatorCell: UICollectionViewCell {
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var bottomView: UIView!
    
    @IBOutlet weak var marketCapTitleLabel: UILabel!
    @IBOutlet weak var marketCapContentLabel: UILabel!
    @IBOutlet weak var marketCapChangeLabel: MarketColoredLabel!
    
    @IBOutlet weak var volumeTitleLabel: UILabel!
    @IBOutlet weak var volumeContentLabel: UILabel!
    @IBOutlet weak var volumeChangeLabel: MarketColoredLabel!
    
    @IBOutlet weak var btcDominanceTitleLabel: UILabel!
    @IBOutlet weak var btcDominanceContentLabel: UILabel!
    @IBOutlet weak var btcDominanceChartView: UIView!
    @IBOutlet weak var btcProportionView: UIView!
    @IBOutlet weak var btcPercentageTitleLabel: UILabel!
    @IBOutlet weak var btcPercentageContentLabel: UILabel!
    @IBOutlet weak var otherPercentageTitleLabel: UILabel!
    @IBOutlet weak var otherPercentageContentLabel: UILabel!
    
    @IBOutlet var tokenSampleViews: [UIView]!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let borderColor = R.color.line()!.cgColor
        topView.layer.borderColor = borderColor
        topView.layer.borderWidth = 1
        topView.layer.cornerRadius = 8
        topView.layer.masksToBounds = true
        bottomView.layer.borderColor = borderColor
        bottomView.layer.borderWidth = 1
        bottomView.layer.cornerRadius = 8
        bottomView.layer.masksToBounds = true
        marketCapTitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        marketCapChangeLabel.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .medium),
            adjustForContentSize: true
        )
        volumeTitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        volumeChangeLabel.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .medium),
            adjustForContentSize: true
        )
        btcDominanceTitleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        marketCapTitleLabel.text = R.string.localizable.global_market_cap()
        volumeTitleLabel.text = R.string.localizable.volume_24h()
        btcDominanceTitleLabel.text = R.string.localizable.bitcoin_dominance()
        btcDominanceChartView.layer.cornerRadius = 2
        btcDominanceChartView.layer.masksToBounds = true
        otherPercentageTitleLabel.text = R.string.localizable.other().uppercased()
        for view in tokenSampleViews {
            view.layer.cornerRadius = 2
            view.layer.masksToBounds = true
        }
    }
    
    func load(indicator: MarketIndicator) {
        marketCapContentLabel.text = indicator.marketCap
        marketCapChangeLabel.text = indicator.marketCapChange
        marketCapChangeLabel.marketColor = indicator.marketCapColor
        volumeContentLabel.text = indicator.volume
        volumeChangeLabel.text = indicator.volumeChange
        volumeChangeLabel.marketColor = indicator.volumeColor
        btcDominanceContentLabel.text = indicator.btcPercentageString
        btcProportionView.snp.remakeConstraints { make in
            make.width.equalToSuperview().multipliedBy(indicator.btcPercentage)
        }
        btcPercentageContentLabel.text = indicator.btcPercentageString
        otherPercentageContentLabel.text = indicator.otherPercentageString
    }
    
}
