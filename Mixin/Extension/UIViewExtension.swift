import UIKit

extension UIView {
    
    var windowSafeAreaInsets: UIEdgeInsets {
        window?.safeAreaInsets
        ?? UIApplication.shared.firstWindowScene?.keyWindow?.safeAreaInsets
        ?? .zero
    }
    
}

extension UIView.AnimationOptions {
    
    static let overdampedCurve = UIView.AnimationOptions(rawValue: UInt(7 << 16))
    
}

extension UILayoutPriority {
    
    static let almostRequired = UILayoutPriority(999)
    static let medium = UILayoutPriority(500)
    static let almostInexist = UILayoutPriority(1)
    
}

extension UIVisualEffect {
    
    static let extraLightBlur = UIBlurEffect(style: .extraLight)
    static let lightBlur = UIBlurEffect(style: .light)
    static let darkBlur = UIBlurEffect(style: .dark)
    static let regularBlur = UIBlurEffect(style: .regular)
    static let prominentBlur = UIBlurEffect(style: .prominent)
    
}
