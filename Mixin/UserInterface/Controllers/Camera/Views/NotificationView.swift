import UIKit

class NotificationView: UIView {
    
    @IBOutlet weak var blurEffectView: UIVisualEffectView!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    private let shadowLayer = CAShapeLayer()
    private let shadowMaskLayer = CAShapeLayer()
    
    private var lastBlurEffectViewFrame = CGRect.zero
    
    override func awakeFromNib() {
        super.awakeFromNib()
        shadowMaskLayer.allowsEdgeAntialiasing = false
        shadowMaskLayer.fillColor = UIColor.white.cgColor
        shadowMaskLayer.fillRule = .evenOdd
        shadowLayer.allowsEdgeAntialiasing = false
        shadowLayer.fillColor = UIColor.white.cgColor
        shadowLayer.applySketchShadow(color: .black, alpha: 0.1, x: 0, y: 2, blur: 6, spread: 0)
        shadowLayer.mask = shadowMaskLayer
        layer.insertSublayer(shadowLayer, at: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        shadowLayer.frame = bounds
        shadowMaskLayer.frame = bounds
        if lastBlurEffectViewFrame != blurEffectView.frame {
            let path = UIBezierPath(roundedRect: blurEffectView.frame, cornerRadius: 8)
            shadowLayer.path = path.cgPath
            let maskPath = UIBezierPath(rect: bounds)
            maskPath.append(path)
            shadowMaskLayer.path = maskPath.cgPath
            lastBlurEffectViewFrame = blurEffectView.frame
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.2) {
            self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.2) {
            self.transform = .identity
        }
    }
    
}
