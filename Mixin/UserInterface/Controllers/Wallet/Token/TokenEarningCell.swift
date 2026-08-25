import UIKit

final class TokenEarningCell: UITableViewCell {
    
    @IBOutlet weak var totalEarningsTitleLabel: UILabel!
    @IBOutlet weak var totalEarningsValueLabel: UILabel!
    @IBOutlet weak var infoStackView: UIStackView!
    
    private weak var totalAmountView: ItemView!
    private weak var pendingEarningView: ItemView!
    private weak var rewardRateView: ItemView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        totalEarningsTitleLabel.text = R.string.localizable.earn_total_earnings()
        
        let totalAmountView = ItemView()
        totalAmountView.imageView.image = R.image.earn_total_amount()
        totalAmountView.titleLabel.text = R.string.localizable.total_amount()
        totalAmountView.valueLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        totalAmountView.valueLabel.textColor = R.color.text()
        infoStackView.addArrangedSubview(totalAmountView)
        self.totalAmountView = totalAmountView
        
        let pendingEarningView = ItemView()
        pendingEarningView.imageView.image = R.image.earn_pending_earning()
        pendingEarningView.titleLabel.text = R.string.localizable.earn_pending_earning()
        pendingEarningView.valueLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        pendingEarningView.valueLabel.textColor = R.color.text_quaternary()
        infoStackView.addArrangedSubview(pendingEarningView)
        self.pendingEarningView = pendingEarningView
        
        let rewardRateView = ItemView()
        rewardRateView.imageView.image = R.image.earn_reward_rate()
        rewardRateView.titleLabel.text = R.string.localizable.earn_reward_rate()
        rewardRateView.valueLabel.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .medium),
            adjustForContentSize: true
        )
        rewardRateView.valueLabel.marketColor = .rising
        infoStackView.addArrangedSubview(rewardRateView)
        self.rewardRateView = rewardRateView
    }
    
    func load(earning: TokenEarningViewModel) {
        totalEarningsValueLabel.text = earning.totalEarnings
        totalAmountView.valueLabel.text = earning.totalAmount
        pendingEarningView.valueLabel.text = earning.pendingEarning
        if let rate = earning.rewardRate {
            rewardRateView.valueLabel.text = rate
            rewardRateView.isHidden = false
        } else {
            rewardRateView.isHidden = true
        }
    }
    
}

extension TokenEarningCell {
    
    private final class ItemView: UIStackView {
        
        let imageView = UIImageView()
        let titleLabel = UILabel()
        let valueLabel = MarketColoredLabel()
        
        init() {
            super.init(frame: .zero)
            
            axis = .horizontal
            distribution = .fill
            alignment = .center
            spacing = 8
            
            imageView.tintColor = R.color.text_tertiary()
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            titleLabel.textColor = R.color.text_tertiary()
            titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            
            valueLabel.textAlignment = .right
            valueLabel.adjustsFontSizeToFitWidth = true
            valueLabel.minimumScaleFactor = 0.5
            valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            
            addArrangedSubview(imageView)
            addArrangedSubview(titleLabel)
            addArrangedSubview(valueLabel)
        }
        
        required init(coder: NSCoder) {
            fatalError("Storyboard/Xib not supported")
        }
        
    }
    
}

