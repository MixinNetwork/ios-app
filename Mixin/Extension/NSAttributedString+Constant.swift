import UIKit
import RswiftResources

extension NSAttributedString {
    
    static func agreement() -> NSAttributedString {
        let intro = R.string.localizable.agree_hint(R.string.localizable.terms_of_service(), R.string.localizable.privacy_policy())
        let nsIntro = intro as NSString
        let fullRange = NSRange(location: 0, length: nsIntro.length)
        let termsRange = nsIntro.range(of: R.string.localizable.terms_of_service())
        let privacyRange = nsIntro.range(of: R.string.localizable.privacy_policy())
        let attributedText = NSMutableAttributedString(string: intro)
        let paragraphSytle = NSMutableParagraphStyle()
        paragraphSytle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 13)),
            .paragraphStyle: paragraphSytle,
            .foregroundColor: R.color.text_quaternary()!
        ]
        attributedText.setAttributes(attrs, range: fullRange)
        attributedText.addAttributes([NSAttributedString.Key.link: URL.terms], range: termsRange)
        attributedText.addAttributes([NSAttributedString.Key.link: URL.privacy], range: privacyRange)
        return attributedText
    }
    
    static func walletIntroduction() -> NSAttributedString {
        .linkedMoreInfo(
            content: R.string.localizable.recovery_kit_instruction,
            font: UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14)),
            color: R.color.text_secondary()!,
            moreInfoURL: .tip
        )
    }
    
    static func orderedList(
        items: [String],
        font: UIFont = .systemFont(ofSize: 14),
        indentation: CGFloat = 20,
        lineSpacing: CGFloat = 2,
        paragraphSpacing: CGFloat = 12,
        textColor: (Int) -> UIColor
    ) -> NSAttributedString {
        let numbers = ["➊", "➋", "➌", "➍", "➎", "➏", "➐", "➑", "➒", "➓"]
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = [
            NSTextTab(textAlignment: .left, location: indentation)
        ]
        paragraphStyle.defaultTabInterval = indentation
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.headIndent = indentation
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: R.color.text_tertiary()!,
            .paragraphStyle: paragraphStyle,
        ]
        
        let attributedString = NSMutableAttributedString()
        for (index, item) in items.enumerated() {
            if index < numbers.count {
                let number = NSAttributedString(string: "\(numbers[index])\t", attributes: attributes)
                attributedString.append(number)
            } else {
                assertionFailure("Numbers not enough")
                let number = NSAttributedString(string: " \t", attributes: attributes)
                attributedString.append(number)
            }
            
            var itemAttributes = attributes
            itemAttributes[.foregroundColor] = textColor(index)
            let attributedItem = if index == items.count - 1 {
                NSAttributedString(string: item, attributes: itemAttributes)
            } else {
                NSAttributedString(string: item + "\n", attributes: itemAttributes)
            }
            attributedString.append(attributedItem)
        }
        return attributedString
    }
    
    static func linkedMoreInfo(
        content: RswiftResources.StringResource1<String>,
        font: UIFont,
        color: UIColor,
        moreInfoURL: URL
    ) -> NSAttributedString {
        let moreInfo = R.string.localizable.more_information()
        let string = content(moreInfo)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.lineHeightMultiple = 1.5
                return style
            }(),
        ]
        let attributedString = NSMutableAttributedString(string: string, attributes: attributes)
        let range = (string as NSString).range(of: moreInfo, options: .backwards)
        attributedString.addAttribute(.link, value: moreInfoURL, range: range)
        attributedString.addAttribute(.foregroundColor, value: R.color.theme()!, range: range)
        return attributedString
    }
    
}
