import UIKit

class LoginContinueButton: StateResponsiveButton {
    
    static let size = CGSize(width: 60, height: 60)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        activityIndicator.activityIndicatorViewStyle = .white
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        activityIndicator.activityIndicatorViewStyle = .white
    }
    
    override var intrinsicContentSize: CGSize {
        return LoginContinueButton.size
    }
    
    override func updateWithIsEnabled() {
        alpha = isEnabled ? 1 : 0
    }
    
}
