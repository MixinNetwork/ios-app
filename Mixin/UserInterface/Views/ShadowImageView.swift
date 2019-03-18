import UIKit

class ShadowImageView: UIImageView {

    @IBInspectable
    var shadowColor: UIColor?

    @IBInspectable
    var shadowAlpha: Float = 1

    @IBInspectable
    var shadowX: CGFloat = 0

    @IBInspectable
    var shadowY: CGFloat = 0

    @IBInspectable
    var shadowBlur: CGFloat = 0

    @IBInspectable
    var shadowSpread: CGFloat = 0

    override func awakeFromNib() {
        super.awakeFromNib()

        if let color = shadowColor {
            layer.applySketchShadow(color: color, alpha: shadowAlpha, x: shadowX, y: shadowY, blur: shadowBlur, spread: shadowSpread)
        }
    }
}
