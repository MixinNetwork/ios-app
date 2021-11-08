import UIKit

class PinSettingTableHeaderView: UIView {

    @IBOutlet weak var textView: UITextView!

    @IBOutlet weak var textViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewBottomConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineHeightMultiple = 1.44
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.scaledFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.accessoryText,
            .paragraphStyle: paragraphStyle
        ]
        let text = R.string.localizable.setting_pin_hint()
        let attributedText = NSMutableAttributedString(string: text, attributes: attrs)
        let linkRange = (text as NSString).range(of: R.string.localizable.action_learn_more(), options: [.backwards, .caseInsensitive])
        if linkRange.location != NSNotFound && linkRange.length != 0 {
            attributedText.addAttribute(.link, value: URL.pinTIP, range: linkRange)
        }
        textView.attributedText = attributedText
        textView.sizeToFit()
        frame.size.height = textViewTopConstraint.constant + textViewBottomConstraint.constant + textView.contentSize.height
    }
    
}
