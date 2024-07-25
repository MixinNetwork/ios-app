import UIKit
import MixinServices

final class SwapAssetChangeCell: UITableViewCell {
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    
    private let receivingView = RowStackView()
    private let sendingView = RowStackView()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentStackView.addArrangedSubview(receivingView)
        contentStackView.addArrangedSubview(sendingView)
        contentStackView.setCustomSpacing(12, after: receivingView)
        titleLabel.text = R.string.localizable.swap_asset_change().uppercased()
        receivingView.amountLabel.textColor = R.color.green()
        sendingView.amountLabel.textColor = R.color.text()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        receivingView.iconView.sd_cancelCurrentImageLoad()
        sendingView.iconView.sd_cancelCurrentImageLoad()
    }
    
    func reloadData(
        sendToken: TokenItem,
        sendAmount: String,
        receiveToken: SwappableToken,
        receiveAmount: String
    ) {
        receivingView.iconView.sd_setImage(with: receiveToken.iconURL,
                                           placeholderImage: nil,
                                           context: assetIconContext)
        receivingView.amountLabel.text = receiveAmount
        receivingView.networkLabel.text = receiveToken.chain.name
        
        sendingView.iconView.sd_setImage(with: URL(string: sendToken.iconURL),
                                         placeholderImage: nil,
                                         context: assetIconContext)
        sendingView.amountLabel.text = sendAmount
        sendingView.networkLabel.text = sendToken.chain?.name
    }
    
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
