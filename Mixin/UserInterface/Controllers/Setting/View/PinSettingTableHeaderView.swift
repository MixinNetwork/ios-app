import UIKit

class PinSettingTableHeaderView: UIView {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewTrailingConstraint: NSLayoutConstraint!
    
    private let textViewBottomMargin: CGFloat = 30
    
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
            textView.linkTextAttributes = [.foregroundColor: UIColor.theme]
        }
        textView.attributedText = attributedText
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let textViewWidthToFit = size.width
            - textViewLeadingConstraint.constant
            - textViewTrailingConstraint.constant
        let textViewSizeToFit = CGSize(width: textViewWidthToFit, height: size.height)
        let textViewHeight = textView.sizeThatFits(textViewSizeToFit).height
        let height = imageViewTopConstraint.constant
            + (imageView.image?.size.height ?? 68)
            + textViewTopConstraint.constant
            + textViewHeight
            + textViewBottomMargin
        return CGSize(width: size.width, height: ceil(height))
    }
    
}
