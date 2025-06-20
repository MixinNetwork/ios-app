import UIKit
import MixinServices

final class DepositSuspendedView: UIView {
    
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
    
    private func description(symbol: String) -> NSAttributedString {
        let string = R.string.localizable.suspended_deposit(symbol, symbol)
        let attributes: [NSAttributedString.Key: Any] = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 5
            style.alignment = .center
            return [
                .paragraphStyle: style.copy(),
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
        }()
        return NSAttributedString(string: string, attributes: attributes)
    }
    
}
