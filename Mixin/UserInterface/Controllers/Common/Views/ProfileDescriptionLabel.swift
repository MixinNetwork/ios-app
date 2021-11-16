import UIKit

class ProfileDescriptionLabel: TextLabel {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if selectedLink == nil {
            if UIMenuController.shared.isMenuVisible {
                UIMenuController.shared.setMenuVisible(false, animated: true)
            } else {
                perform(#selector(showCopyMenu), with: nil, afterDelay: longPressDuration)
            }
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return action == #selector(copy(_:))
    }
    
    @objc private func showCopyMenu() {
        becomeFirstResponder()
        UIMenuController.shared.setTargetRect(bounds, in: self)
        UIMenuController.shared.setMenuVisible(true, animated: true)
    }
    
    override func copy(_ sender: Any?) {
        UIPasteboard.general.string = text
    }
    
}
