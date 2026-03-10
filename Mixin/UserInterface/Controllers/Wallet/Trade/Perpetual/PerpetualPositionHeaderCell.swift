import UIKit

final class PerpetualPositionHeaderCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: MarketColoredLabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var directionLabel: InsetLabel!
    @IBOutlet weak var actionView: PillActionView!
    
    @IBOutlet weak var titleTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var directionTopConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        symbolLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 5, right: 0)
        directionLabel.contentInset = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        directionLabel.layer.cornerRadius = 4
        directionLabel.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        switch viewModel.state {
        case .open:
            titleTopConstraint.constant = 15
            directionTopConstraint.constant = 16
            titleLabel.text = viewModel.directionWithSymbol
            titleLabel.font = .systemFont(ofSize: 24, weight: .medium)
            titleLabel.textColor = R.color.text()
            symbolLabel.text = nil
            symbolLabel.isHidden = true
        case .closed:
            titleTopConstraint.constant = 7
            directionTopConstraint.constant = 10
            titleLabel.text = viewModel.pnlAmount
            titleLabel.font = .condensed(size: 34)
            titleLabel.marketColor = viewModel.pnlColor
            symbolLabel.text = "USDT"
            symbolLabel.isHidden = false
        }
        switch viewModel.leverage {
        case .long(let value):
            let color = MarketColor.rising.uiColor
            directionLabel.text = "Long \(value)"
            directionLabel.backgroundColor = color.withAlphaComponent(0.2)
            directionLabel.textColor = color
        case .short(let value):
            let color = MarketColor.falling.uiColor
            directionLabel.text = "Short \(value)"
            directionLabel.backgroundColor = color.withAlphaComponent(0.2)
            directionLabel.textColor = color
        }
    }
    
}
