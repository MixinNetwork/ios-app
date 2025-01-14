import UIKit
import MixinServices

final class MultipleAssetChangeCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    
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
    
    func reloadData(changes: [(token: TokenItem, amount: String)]) {
        titleLabel.text = R.string.localizable.asset_changes().uppercased()
        loadRowViews(count: changes.count)
        for (i, change) in changes.enumerated() {
            let rowView = rowViews[i]
            rowView.iconView.setIcon(token: change.token)
            rowView.amountLabel.text = change.amount
            rowView.networkLabel.text = change.token.chain?.name
            rowView.amountLabel.textColor = R.color.text()
        }
    }
    
    func reloadData(
        sendToken: TokenItem,
        sendAmount: String,
        receiveToken: SwapToken,
        receiveAmount: String
    ) {
        titleLabel.text = R.string.localizable.asset_changes_estimate().uppercased()
        
        loadRowViews(count: 2)
        let sendingView = rowViews[0]
        let receivingView = rowViews[1]
        
        receivingView.iconView.setIcon(token: receiveToken)
        receivingView.amountLabel.text = receiveAmount
        receivingView.networkLabel.text = receiveToken.chain.name
        receivingView.amountLabel.textColor = R.color.market_green()
        
        sendingView.iconView.setIcon(token: sendToken)
        sendingView.amountLabel.text = sendAmount
        sendingView.networkLabel.text = sendToken.chain?.name
        sendingView.amountLabel.textColor = R.color.text()
    }
    
    func loadRowViews(count: Int) {
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
    
    private class RowStackView: UIStackView {
        
        let iconView = PlainTokenIconView(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        let amountLabel = UILabel()
        let networkLabel = UILabel()
        
        init() {
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            iconView.setContentCompressionResistancePriority(.required, for: .horizontal)
            
            amountLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
            amountLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            amountLabel.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
            amountLabel.adjustsFontSizeToFitWidth = true
            amountLabel.minimumScaleFactor = 0.1
            
            networkLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            networkLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            networkLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            networkLabel.textColor = R.color.text_tertiary()
            
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
        }
        
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
    }
    
}
