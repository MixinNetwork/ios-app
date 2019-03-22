import UIKit

extension UILabel {

    func applySketchLineHeight(sketchLineHeight: CGFloat, sketchFontSize: CGFloat) {
        guard let text = self.text else {
            return
        }
        let attributedString = NSMutableAttributedString(string: text)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = self.textAlignment
        paragraphStyle.lineSpacing = sketchLineHeight - sketchFontSize - (font.lineHeight - font.pointSize)
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSMakeRange(0, attributedString.length))
        attributedText = attributedString
    }

}
