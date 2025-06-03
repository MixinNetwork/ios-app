import UIKit

final class DestructiveRoundedButton: RoundedButton {

    override var backgroundEnableColor: UIColor {
        R.color.error_red()!
    }
    
}
