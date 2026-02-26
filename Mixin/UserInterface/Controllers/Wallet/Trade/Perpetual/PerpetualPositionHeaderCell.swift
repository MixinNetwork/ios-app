import UIKit

final class PerpetualPositionHeaderCell: UICollectionViewCell {
    
    @IBOutlet weak var iconView: PlainTokenIconView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var directionLabel: InsetLabel!
    @IBOutlet weak var actionView: PillActionView!
    
    @IBOutlet weak var titleTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var directionTopConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        symbolLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 2, right: 0)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.prepareForReuse()
    }
    
    func load(viewModel: PerpetualPositionViewModel) {
        iconView.setIcon(tokenIconURL: viewModel.iconURL)
        if let pnl = viewModel.pnl {
            titleTopConstraint.constant = 7
            directionTopConstraint.constant = 10
            titleLabel.text = pnl.count
            titleLabel.font = .condensed(size: 34)
            titleLabel.textColor = R.color.text()
            symbolLabel.text = pnl.symbol
            symbolLabel.isHidden = false
        } else {
            titleTopConstraint.constant = 15
            directionTopConstraint.constant = 16
            titleLabel.text = viewModel.directionWithSymbol
            titleLabel.font = .systemFont(ofSize: 24, weight: .medium)
            titleLabel.textColor = R.color.text()
            symbolLabel.text = nil
            symbolLabel.isHidden = true
        }
    }
    
}
