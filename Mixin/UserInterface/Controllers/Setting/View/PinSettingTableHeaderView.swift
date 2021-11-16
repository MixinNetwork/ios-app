import UIKit

class PinSettingTableHeaderView: UIView {
    
    @IBOutlet weak var textLabel: TextLabel!
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelBottomConstraint: NSLayoutConstraint!
    
    var contentHeight: CGFloat {
        imageViewTopConstraint.constant
            + (imageView.image?.size.height ?? 68)
            + textLabelTopConstraint.constant
            + textLabel.intrinsicContentSize.height
            + textLabelBottomConstraint.constant
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textLabel.delegate = self
        textLabel.textColor = .accessoryText
        textLabel.lineSpacing = 10
        textLabel.linkColor = .theme
        let text = R.string.localizable.setting_pin_hint()
        let linkRange = (text as NSString).range(of: R.string.localizable.action_learn_more(), options: [.backwards, .caseInsensitive])
        if linkRange.location != NSNotFound && linkRange.length != 0 {
            textLabel.linksMap = [linkRange: URL.pinTIP]
        }
        textLabel.text = text
    }

}

extension PinSettingTableHeaderView: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }

}
