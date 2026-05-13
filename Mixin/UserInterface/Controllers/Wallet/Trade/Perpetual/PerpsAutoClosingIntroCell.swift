import UIKit

final class PerpsAutoClosingIntroCell: UICollectionViewCell {
    
    protocol Delegate: AnyObject {
        func perpsAutoClosingIntroCell(_ cell: PerpsAutoClosingIntroCell, didRejectSuggestion suggestion: PerpsAutoClosingCondition.Behavior)
        func perpsAutoClosingIntroCell(_ cell: PerpsAutoClosingIntroCell, didAcceptSuggestion suggestion: PerpsAutoClosingCondition.Behavior)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var performSuggestionButton: UIButton!
    
    var suggestion: PerpsAutoClosingCondition.Behavior? {
        didSet {
            if let suggestion {
                reload(suggestion: suggestion)
            }
        }
    }
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
    }
    
    @IBAction func requestDismiss(_ sender: Any) {
        guard let suggestion else {
            return
        }
        delegate?.perpsAutoClosingIntroCell(self, didRejectSuggestion: suggestion)
    }
    
    @IBAction func performSuggestion(_ sender: Any) {
        guard let suggestion else {
            return
        }
        delegate?.perpsAutoClosingIntroCell(self, didAcceptSuggestion: suggestion)
    }
    
    private func reload(suggestion: PerpsAutoClosingCondition.Behavior) {
        var buttonAttributes = AttributeContainer()
        buttonAttributes.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        switch suggestion {
        case .takeProfit:
            imageView.image = R.image.take_profit_intro()
            titleLabel.text = R.string.localizable.lock_in_profits()
            descriptionLabel.text = R.string.localizable.lock_in_profits_description()
            performSuggestionButton.configuration?.attributedTitle = AttributedString(
                R.string.localizable.take_profit(),
                attributes: buttonAttributes
            )
        case .stopLoss:
            imageView.image = R.image.stop_loss_intro()
            titleLabel.text = R.string.localizable.prevent_further_loss()
            descriptionLabel.text = R.string.localizable.prevent_further_loss_description()
            performSuggestionButton.configuration?.attributedTitle = AttributedString(
                R.string.localizable.stop_loss(),
                attributes: buttonAttributes
            )
        }
    }
    
}
