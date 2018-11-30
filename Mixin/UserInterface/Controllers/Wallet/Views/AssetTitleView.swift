import UIKit

class AssetTitleView: UIView, XibDesignable {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var iconImageView: CornerImageView!
    @IBOutlet weak var chainImageView: CornerImageView!
    @IBOutlet weak var amountLabel: InsetLabel!
    @IBOutlet weak var symbolLabel: UILabel!
    @IBOutlet weak var usdAmountLabel: UILabel!
    @IBOutlet weak var actionButtonsStackView: UIStackView!
    @IBOutlet weak var actionButtonsSeparatorView: UIView!
    @IBOutlet weak var transferButton: UIButton!
    @IBOutlet weak var depositButton: BusyButton!
    
    @IBOutlet weak var contentStackViewToCardViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentStackViewToActionButtonsBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet var AmountLabelConcernedHorizontalConstraints: [NSLayoutConstraint]!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        amountLabel.preferredMaxLayoutWidth = amountLabelPreferredMaxLayoutWidthThatFits(size.width)
        let sizeToFit = CGSize(width: size.width, height: UIView.layoutFittingExpandedSize.height)
        let layoutSize = systemLayoutSizeFitting(sizeToFit)
        return CGSize(width: size.width, height: layoutSize.height)
    }
    
    func render(asset: AssetItem) {
        reloadIcon(asset: asset)
        if asset.balance == "0" {
            amountLabel.text = "0.00"
            usdAmountLabel.text = "≈ $0.00"
        } else {
            amountLabel.text = asset.balance
            let usdBalance = asset.priceUsd.doubleValue * asset.balance.doubleValue
            if let localizedUSDBalance = CurrencyFormatter.localizedString(from: usdBalance, format: .legalTender, sign: .never) {
                usdAmountLabel.text = "≈ $" + localizedUSDBalance
            } else {
                usdAmountLabel.text = nil
            }
        }
        symbolLabel.text = asset.symbol
        depositButton.isBusy = !(asset.isAccount || asset.isAddress)
        actionButtonsStackView.isHidden = false
        actionButtonsSeparatorView.isHidden = false
        contentStackViewToCardViewBottomConstraint.priority = .defaultLow
        contentStackViewToActionButtonsBottomConstraint.priority = .defaultHigh
    }
    
    func render(asset: AssetItem, snapshot: SnapshotItem) {
        reloadIcon(asset: asset)
        switch snapshot.type {
        case SnapshotType.deposit.rawValue, SnapshotType.rebate.rawValue:
            amountLabel.textColor = .walletGreen
        case SnapshotType.transfer.rawValue:
            if snapshot.amount.hasMinusPrefix {
                amountLabel.textColor = .walletRed
            } else {
                amountLabel.textColor = .walletGreen
            }
        case SnapshotType.withdrawal.rawValue, SnapshotType.fee.rawValue:
            amountLabel.textColor = .walletRed
        default:
            break
        }
        amountLabel.text = CurrencyFormatter.localizedString(from: snapshot.amount, format: .precision, sign: .always)
        symbolLabel.text = asset.symbol
        let usdAmount = snapshot.amount.doubleValue * asset.priceUsd.doubleValue
        if let value = CurrencyFormatter.localizedString(from: usdAmount, format: .legalTender, sign: .never) {
            usdAmountLabel.text = "≈ $" + value
        } else {
            usdAmountLabel.text = nil
        }
        actionButtonsStackView.isHidden = true
        actionButtonsSeparatorView.isHidden = true
        contentStackViewToCardViewBottomConstraint.priority = .defaultHigh
        contentStackViewToActionButtonsBottomConstraint.priority = .defaultLow
    }
    
    private func reloadIcon(asset: AssetItem) {
        iconImageView.sd_cancelCurrentImageLoad()
        chainImageView.sd_cancelCurrentImageLoad()
        if let url = URL(string: asset.iconUrl) {
            iconImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), completed: nil)
        }
        if let chainIconUrl = asset.chainIconUrl, let url = URL(string: chainIconUrl) {
            chainImageView.sd_setImage(with: url, placeholderImage: #imageLiteral(resourceName: "ic_place_holder"), completed: nil)
            chainImageView.isHidden = false
        } else {
            chainImageView.isHidden = true
        }
    }
    
    private func amountLabelPreferredMaxLayoutWidthThatFits(_ containerWidth: CGFloat) -> CGFloat {
        var width = AmountLabelConcernedHorizontalConstraints.reduce(0) { (width, constraint) -> CGFloat in
            return width + constraint.constant
        }
        width += contentStackView.spacing
        width += symbolLabel.intrinsicContentSize.width
        return containerWidth - width
    }
    
    private func prepare() {
        loadXib()
        amountLabel.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
    }
    
}
