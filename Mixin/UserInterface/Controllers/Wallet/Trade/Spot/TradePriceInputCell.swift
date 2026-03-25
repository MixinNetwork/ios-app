import UIKit

final class TradePriceInputCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var networkLabel: UILabel!
    @IBOutlet weak var inputStackView: UIStackView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var priceRepresentationLabel: UILabel!
    @IBOutlet weak var togglePriceUnitImageView: UIImageView!
    @IBOutlet weak var tokenNameLabel: UILabel!
    @IBOutlet weak var loadingIndicator: ActivityIndicatorView!
    @IBOutlet weak var togglePriceUnitButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.masksToBounds = true
        contentView.layer.cornerRadius = 8
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.price()
        symbolLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
    }
    
    func update(style: TradeTokenSelectorStyle) {
        UIView.performWithoutAnimation {
            switch style {
            case .loading:
                inputStackView.alpha = 0
                tokenIconView.isHidden = false
                networkLabel.text = "Placeholder"
                networkLabel.alpha = 0 // Keeps the height
                tokenNameLabel.text = nil
                loadingIndicator.startAnimating()
            case .selectable:
                inputStackView.alpha = 1
                tokenIconView.isHidden = true
                tokenIconView.prepareForReuse()
                symbolLabel.text = R.string.localizable.select_token()
                networkLabel.text = "Placeholder"
                networkLabel.alpha = 0 // Keeps the height
                tokenNameLabel.text = nil
                loadingIndicator.stopAnimating()
            case .token(let token):
                inputStackView.alpha = 1
                tokenIconView.isHidden = false
                tokenIconView.setIcon(swappableToken: token)
                symbolLabel.text = token.symbol
                networkLabel.text = token.chain.name
                networkLabel.alpha = 1
                tokenNameLabel.text = token.name
                loadingIndicator.stopAnimating()
            }
        }
    }
    
    func load(priceRepresentation: String?) {
        priceRepresentationLabel.text = priceRepresentation
        if priceRepresentation == nil {
            togglePriceUnitImageView.alpha = 0
        } else {
            togglePriceUnitImageView.alpha = 1
        }
    }
    
}
