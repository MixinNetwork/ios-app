import UIKit

class KeyboardBasedLayoutViewController: UIViewController {
    
    private(set) var viewHasAppeared = false
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewHasAppeared = true
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        if viewHasAppeared {
            layout(for: endFrame)
        } else {
            UIView.performWithoutAnimation {
                layout(for: endFrame)
            }
        }
    }
    
    func layout(for keyboardFrame: CGRect) {
        
    }
    
}
