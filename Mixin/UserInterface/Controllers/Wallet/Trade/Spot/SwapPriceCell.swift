import UIKit

final class SwapPriceCell: UICollectionViewCell {
    
    @IBOutlet weak var footerInfoButton: UIButton!
    @IBOutlet weak var footerInfoProgressView: CircularProgressView!
    @IBOutlet weak var footerSpacingView: UIView!
    @IBOutlet weak var togglePriceUnitButton: UIButton!
    @IBOutlet weak var advancedTradingHintStackView: UIStackView!
    @IBOutlet weak var advancedTradingHintButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        footerInfoButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .regular),
            adjustForContentSize: true
        )
        advancedTradingHintButton.configuration = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 14, weight: .medium)
            )
            attributes.foregroundColor = R.color.theme()
            var config: UIButton.Configuration = .plain()
            config.attributedTitle = AttributedString(
                R.string.localizable.advanced_trade(),
                attributes: attributes,
            )
            config.image = R.image.ic_accessory_disclosure()?.withRenderingMode(.alwaysTemplate)
            config.imagePadding = 10
            config.imagePlacement = .trailing
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            return config
        }()
        advancedTradingHintButton.tintColor = R.color.theme()
    }
    
}

extension SwapPriceCell {
    
    enum Content {
        case calculating
        case error(description: String, advancedTradingHint: Bool)
        case price(String)
    }
    
    func setContent(_ content: Content?) {
        switch content {
        case .calculating:
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(R.string.localizable.calculating(), for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            togglePriceUnitButton.isHidden = true
            advancedTradingHintStackView.isHidden = true
        case let .error(description, advancedTradingHint):
            footerInfoButton.setTitleColor(R.color.red(), for: .normal)
            footerInfoButton.setTitle(description, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            togglePriceUnitButton.isHidden = true
            advancedTradingHintStackView.isHidden = !advancedTradingHint
        case .price(let price):
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(price, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = false
            footerSpacingView.isHidden = false
            togglePriceUnitButton.isHidden = false
            advancedTradingHintStackView.isHidden = true
        case nil:
            footerInfoButton.isHidden = true
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            togglePriceUnitButton.isHidden = true
            advancedTradingHintStackView.isHidden = true
        }
    }
    
}
