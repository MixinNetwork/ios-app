import UIKit

class AppButton: UIButton {
    
    override var backgroundColor: UIColor? {
        get { R.color.chat_button_background() }
        set { }
    }
    
    convenience init() {
        self.init(type: .system)
        super.backgroundColor = R.color.chat_button_background()
    }
    
}
