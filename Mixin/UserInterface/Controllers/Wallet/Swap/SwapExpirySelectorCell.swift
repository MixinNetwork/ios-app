import UIKit

final class SwapExpirySelectorCell: UICollectionViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    
    private let buttonAttributes = {
        var container = AttributeContainer()
        container.font = UIFontMetrics.default.scaledFont(
            for: .systemFont(ofSize: 14)
        )
        container.foregroundColor = R.color.text_tertiary()
        return container
    }()
    
    var selectedExpiry: LimitOrder.Expiry = .never {
        didSet {
            button.configuration?.attributedTitle = AttributedString(
                selectedExpiry.localizedName,
                attributes: buttonAttributes
            )
            button.menu = UIMenu(children: LimitOrder.Expiry.allCases.map { expiry in
                UIAction(
                    title: expiry.localizedName,
                    state: selectedExpiry == expiry ? .on : .off,
                    handler: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.selectedExpiry = expiry
                        self.onChange?(expiry)
                    }
                )
            })
        }
    }
    
    var onChange: ((LimitOrder.Expiry) -> Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        titleLabel.text = R.string.localizable.swap_expiry()
        button.showsMenuAsPrimaryAction = true
    }
    
}
