import UIKit

extension UIWindow {
    
    static var statusBarHeight: CGFloat {
        UIApplication.shared.keyWindow?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }
    
    static var isLandscape: Bool {
        UIApplication.shared.keyWindow?.windowScene?.interfaceOrientation.isLandscape ?? false
    }
    
    static var isPortrait: Bool {
        UIApplication.shared.keyWindow?.windowScene?.interfaceOrientation.isPortrait ?? false
    }
    
}
