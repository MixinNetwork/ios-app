import UIKit
import MixinServices

final class MultipleAssetChangeCell: UITableViewCell {
    
    typealias PerpsPosition = (iconURL: URL?, name: String, side: PerpetualOrderSide, leverage: String?)
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var contentTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    private var rowViews: [RowStackView] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.setCustomSpacing(8, after: titleLabel)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        for iconView in rowViews.map(\.iconView) {
            iconView.prepareForReuse()
        }
    }
    
    func reloadData(
        numberOfAssetChanges: Int,
        configureRow: (Int, RowStackView) -> Void
    ) {
        loadRowViews(count: numberOfAssetChanges)
        for i in 0..<numberOfAssetChanges {
            configureRow(i, rowViews[i])
        }
    }
    
    func reloadData(changes: [StyledAssetChange]) {
        loadRowViews(count: changes.count)
        for (i, change) in changes.enumerated() {
            let rowView = rowViews[i]
            rowView.iconView.setIcon(token: change.token)
            rowView.amountLabel.text = change.amount
            switch change.token {
            case let token as OnChainToken:
                rowView.networkLabel.text = token.chain?.name
            case let token as SwapToken:
                rowView.networkLabel.text = token.chain.name
            default:
                rowView.networkLabel.text = nil
            }
            rowView.amountLabel.textColor = switch change.amountStyle {
            case .income:
                R.color.market_green()
            case .outcome:
                R.color.market_red()
            case .plain:
                R.color.text()
            case .gray:
                R.color.text_tertiary()
            }
            rowView.leverageLabel?.removeFromSuperview()
        }
    }
    
    func reloadData(
        changes: [TradeOrderViewModel.AssetChange],
        style: StyledAssetChange.AmountStyle
    ) {
        loadRowViews(count: changes.count)
        for (i, change) in changes.enumerated() {
            let rowView = rowViews[i]
            rowView.iconView.setIcon(token: change.token)
            rowView.amountLabel.text = change.amount
            rowView.networkLabel.text = change.token?.chain?.name
            rowView.amountLabel.textColor = switch style {
            case .income:
                R.color.market_green()
            case .outcome:
                R.color.market_red()
            case .plain:
                R.color.text()
            case .gray:
                R.color.text_tertiary()
            }
            rowView.leverageLabel?.removeFromSuperview()
        }
    }
    
    func reloadData(
        title: String,
        iconURL: URL?,
        amount: String,
        amountColor: UIColor,
        network: String
    ) {
        titleLabel.text = title.uppercased()
        loadRowViews(count: 1)
        let rowView = rowViews[0]
        rowView.iconView.setIcon(tokenIconURL: iconURL)
        rowView.amountLabel.font = .preferredFont(forTextStyle: .callout)
        rowView.amountLabel.text = amount
        rowView.amountLabel.textColor = amountColor
        rowView.networkLabel.text = network
        rowView.leverageLabel?.removeFromSuperview()
    }
    
    func reloadData(perpsPositions: [PerpsPosition]) {
        titleLabel.text = R.string.localizable.perps_product().uppercased()
        loadRowViews(count: perpsPositions.count)
        for (i, position) in perpsPositions.enumerated() {
            let rowView = rowViews[i]
            rowView.iconView.setIcon(tokenIconURL: position.iconURL)
            rowView.amountLabel.setFont(
                scaledFor: .systemFont(ofSize: 16, weight: .medium),
                adjustForContentSize: true
            )
            rowView.amountLabel.text = position.name
            rowView.amountLabel.textColor = R.color.text()
            if let leverage = position.leverage {
                rowView.loadLeverageLabel(side: position.side, text: leverage)
            } else {
                rowView.leverageLabel?.removeFromSuperview()
            }
            rowView.networkLabel.text = nil
        }
    }
    
    private func loadRowViews(count: Int) {
        let diff = rowViews.count - count
        if diff > 0 {
            for view in rowViews.suffix(diff) {
                view.removeFromSuperview()
            }
            rowViews.removeLast(diff)
        } else if diff < 0 {
            for _ in (0 ..< -diff) {
                let view = RowStackView()
                rowViews.append(view)
                contentStackView.addArrangedSubview(view)
            }
        }
    }
    
}

extension MultipleAssetChangeCell {
    
    final class RowStackView: UIStackView {
        
        let iconView = PlainTokenIconView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        let amountLabel = UILabel()
        let networkLabel = UILabel()
        
        private(set) weak var leverageLabel: LeverageLabel?
        
        init() {
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            amountLabel.setContentHuggingPriority(.medium, for: .horizontal)
            amountLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            amountLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
            amountLabel.adjustsFontSizeToFitWidth = true
            amountLabel.minimumScaleFactor = 0.1
            
            networkLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            networkLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            networkLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            networkLabel.textColor = R.color.text_tertiary()
            networkLabel.textAlignment = .right
            
            super.init(frame: .zero)
            
            axis = .horizontal
            distribution = .fill
            alignment = .center
            spacing = 8
            
            addArrangedSubview(iconView)
            addArrangedSubview(amountLabel)
            addArrangedSubview(networkLabel)
            
            iconView.snp.makeConstraints { make in
                make.width.height.equalTo(24)
            }
            setCustomSpacing(4, after: amountLabel)
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func loadLeverageLabel(side: PerpetualOrderSide, text: String) {
            let label: LeverageLabel
            if let l = self.leverageLabel {
                label = l
            } else {
                label = LeverageLabel()
                label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
                label.setContentCompressionResistancePriority(.required, for: .horizontal)
                self.leverageLabel = label
            }
            if label.superview == nil,
               let index = arrangedSubviews.lastIndex(of: networkLabel)
            {
                insertArrangedSubview(label, at: index)
            }
            label.color = switch side {
            case .long:
                    .long
            case .short:
                    .short
            }
            label.text = text
        }
        
    }
    
}
