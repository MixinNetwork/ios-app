import UIKit

class LineHeightLabel: UILabel {

    @IBInspectable
    var lineHeight: CGFloat = 0 {
        didSet {
            applySketchLineHeight(sketchLineHeight: lineHeight, sketchFontSize: self.font.pointSize)
        }
    }

}
