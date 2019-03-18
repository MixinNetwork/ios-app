import UIKit

class LoginContinueButton: StateResponsiveButton {
    
    static let size = CGSize(width: 44, height: 44)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        activityIndicator.style = .white
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        activityIndicator.style = .white
    }
    
    override var intrinsicContentSize: CGSize {
        return LoginContinueButton.size
    }
    
    override func updateWithIsEnabled() {
        alpha = isEnabled ? 1 : 0
    }
    
}
