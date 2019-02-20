import UIKit

class AssetTableHeaderView: UIView {
    
    @IBOutlet weak var infoStackView: UIStackView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var symbolLabel: InsetLabel!
    @IBOutlet weak var usdValueLabel: UILabel!
    @IBOutlet weak var depositButton: BusyButton!
    @IBOutlet weak var transactionsHeaderView: UIView!
    
    @IBOutlet weak var assetIconViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var infoStackViewTrailingConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        symbolLabel.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 7, right: 0)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        amountLabel.preferredMaxLayoutWidth = amountLabelPreferredMaxLayoutWidthThatFits(size.width)
        let sizeToFit = CGSize(width: size.width, height: UIView.layoutFittingExpandedSize.height)
        let layoutSize = systemLayoutSizeFitting(sizeToFit)
        return CGSize(width: size.width, height: layoutSize.height)
    }
    
    func render(asset: AssetItem) {
        assetIconView.setIcon(asset: asset)
        if asset.balance == "0" {
            amountLabel.text = "0\(currentDecimalSeparator)00"
            usdValueLabel.text = "≈ $0\(currentDecimalSeparator)00"
        } else {
            amountLabel.text = CurrencyFormatter.localizedString(from: asset.balance, format: .precision, sign: .never)
            let usdBalance = asset.priceUsd.doubleValue * asset.balance.doubleValue
            if let localizedUSDBalance = CurrencyFormatter.localizedString(from: usdBalance, format: .legalTender, sign: .never) {
                usdValueLabel.text = "≈ $" + localizedUSDBalance
            } else {
                usdValueLabel.text = nil
            }
        }
        symbolLabel.text = asset.symbol
        depositButton.isBusy = !(asset.isAccount || asset.isAddress)
    }
    
    private func amountLabelPreferredMaxLayoutWidthThatFits(_ containerWidth: CGFloat) -> CGFloat {
        let fixedWidth = infoStackViewLeadingConstraint.constant
            + assetIconViewWidthConstraint.constant
            + infoStackView.spacing
            + symbolLabel.intrinsicContentSize.width
            + infoStackViewTrailingConstraint.constant
        return containerWidth - fixedWidth
    }
    
}
