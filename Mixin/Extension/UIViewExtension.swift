import UIKit

extension UIView {

    var isVisibleInScreen: Bool {
        return self.window == UIApplication.currentActivity()?.view.window
    }

    func takeScreenshot(afterScreenUpdates: Bool = false) -> UIImage? {
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.opaque = isOpaque
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: rendererFormat)

        let snapshotImage = renderer.image { _ in
            drawHierarchy(in: bounds, afterScreenUpdates: afterScreenUpdates)
        }
        return snapshotImage
    }

    func roundCorners(cornerRadius: CGFloat, byRoundingCorners: UIRectCorner = [.topLeft, .topRight]) {
        let maskPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: byRoundingCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        let maskLayer = CAShapeLayer()
        maskLayer.frame = self.bounds
        maskLayer.path = maskPath.cgPath
        self.layer.mask = maskLayer
    }

    func animationSwapImage(newImage: UIImage) {
        UIView.animate(withDuration: 0.15, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { (finished) in
            if let imageView = self as? UIImageView {
                imageView.image = newImage
            } else if let button = self as? UIButton {
                button.setImage(newImage, for: .normal)
            }
            UIView.animate(withDuration: 0.15, animations: {
                self.transform = .identity
            })
        })
    }
}

extension UIViewAnimationCurve {
    
    static let overdamped = UIViewAnimationCurve(rawValue: 7) ?? .easeOut
    
}
