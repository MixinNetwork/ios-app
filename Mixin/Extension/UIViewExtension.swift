import UIKit

extension UIView {
    
    var isVisibleInScreen: Bool {
        return self.window == UIApplication.currentActivity()?.view.window
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

extension UIView.AnimationCurve {
    
    static let overdamped = UIView.AnimationCurve(rawValue: 7) ?? .easeOut
    
}

extension UILayoutPriority {
    
    static let almostRequired = UILayoutPriority(999)
    static let almostInexist = UILayoutPriority(1)
    
}

extension UIVisualEffect {
    
    static let extraLightBlur = UIBlurEffect(style: .extraLight)
    static let lightBlur = UIBlurEffect(style: .light)
    static let darkBlur = UIBlurEffect(style: .dark)
    static let regularBlur = UIBlurEffect(style: .regular)
    static let prominentBlur = UIBlurEffect(style: .prominent)
    
}
