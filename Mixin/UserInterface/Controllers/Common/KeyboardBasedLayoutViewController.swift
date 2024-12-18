import UIKit

class KeyboardBasedLayoutViewController: UIViewController {
    
    private(set) var viewHasAppeared = false
    private(set) var viewIsDisappearing = false
    private(set) var lastKeyboardFrame: CGRect?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
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
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        if let frame = lastKeyboardFrame {
            askForLayout(for: frame)
        }
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard !viewIsDisappearing else {
            return
        }
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        lastKeyboardFrame = endFrame
        askForLayout(for: endFrame)
    }
    
    func layout(for keyboardFrame: CGRect) {
        
    }
    
    private func askForLayout(for keyboardFrame: CGRect) {
        UIView.performWithoutAnimation(view.layoutIfNeeded)
        let frame = view.convert(keyboardFrame, from: UIScreen.main.coordinateSpace)
        let sanitizedFrame: CGRect
        if frame.origin.x > 0 {
            sanitizedFrame = frame
        } else {
            // Fix layout on iPhone 13 Pro with iOS 15.7.1
            sanitizedFrame = CGRect(x: 0, y: view.bounds.height - frame.height, width: frame.width, height: frame.height)
        }
        if viewHasAppeared {
            layout(for: sanitizedFrame)
        } else {
            UIView.performWithoutAnimation {
                layout(for: sanitizedFrame)
            }
        }
    }
    
}
