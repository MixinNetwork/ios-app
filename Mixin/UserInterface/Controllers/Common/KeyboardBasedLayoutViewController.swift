import UIKit

class KeyboardBasedLayoutViewController: UIViewController {
    
    private(set) var viewHasAppeared = false
    private(set) var viewIsDisappearing = false
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        AppDelegate.current.window?.endEditing(true)
        super.viewWillAppear(animated)
        viewIsDisappearing = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewHasAppeared = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewIsDisappearing = true
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        guard !viewIsDisappearing else {
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
