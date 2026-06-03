import UIKit

final class PerpetualTopMoverCell: UICollectionViewCell {
    
    @IBOutlet weak var iconImageView: PlainTokenIconView!
    @IBOutlet weak var leverageLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var changeLabel: MarketColoredLabel!
    
    private let shadowLayer = CALayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        leverageLabel.contentInset = UIEdgeInsets(top: 3, left: 3, bottom: 1, right: 3)
        leverageLabel.font = .condensed(size: 12)
        leverageLabel.layer.cornerRadius = 4
        leverageLabel.layer.masksToBounds = true
        shadowLayer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.04).cgColor
        shadowLayer.shadowOpacity = 1
        shadowLayer.shadowRadius = 2
        shadowLayer.shadowOffset = CGSize(width: 0, height: -1)
        contentView.layer.insertSublayer(shadowLayer, below: leverageLabel.layer)
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        changeLabel.setFont(
            scaledFor: .monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            adjustForContentSize: true
        )
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(
            roundedRect: leverageLabel.bounds,
            cornerRadius: leverageLabel.layer.cornerRadius
        )
        shadowLayer.shadowPath = path.cgPath
        shadowLayer.bounds = leverageLabel.bounds
        shadowLayer.position = leverageLabel.center
    }
    
    func load(viewModel: PerpetualMarketViewModel) {
        iconImageView.setIcon(tokenIconURL: viewModel.iconURL)
        leverageLabel.text = viewModel.leverage
        symbolLabel.text = viewModel.market.tokenSymbol
        changeLabel.text = viewModel.change
        changeLabel.marketColor = viewModel.changeColor
    }
    
}
