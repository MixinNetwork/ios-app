import UIKit
import MixinServices

final class DepositSuspendedView: UIView {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var contactSupportButton: RoundedButton!
    
    var symbol: String? {
        didSet {
            if let symbol {
                label.attributedText = description(symbol: symbol)
            } else {
                label.attributedText = nil
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        contactSupportButton.configuration?.title = R.string.localizable.contact_support()
        contactSupportButton.titleLabel?.adjustsFontForContentSizeCategory = true
    }
    
    private func description(symbol: String) -> NSAttributedString {
        let string = R.string.localizable.deposit_suspended(symbol)
        let attributes: [NSAttributedString.Key: Any] = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 5
            style.alignment = .center
            return [
                .paragraphStyle: style.copy(),
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: R.color.text_secondary()!,
            ]
        }()
        return NSAttributedString(string: string, attributes: attributes)
    }
    
}
