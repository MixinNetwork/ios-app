import UIKit

class LoginNavigationController: UINavigationController {

    let backButton = UIButton()

    var lastKeyboardFrame = CGRect.zero
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.keyWindow?.endEditing(true)
        SignalProtocol.shared.initSignal()
        backButton.setImage(R.image.ic_title_back(), for: .normal)
        backButton.addTarget(self, action: #selector(backAction(sender:)), for: .touchUpInside)
        backButton.alpha = 0
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        backButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(44)
            if #available(iOS 11.0, *) {
                make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
                make.leading.equalTo(self.view.safeAreaLayoutGuide.snp.leadingMargin).offset(10)
            } else {
                make.top.equalTo(self.topLayoutGuide.snp.bottom)
                make.leading.equalTo(self.view.snp.leading).offset(10)
            }
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func backAction(sender: Any) {
        popViewController(animated: true)
    }
    
    @objc func keyboardWillChangeFrame(notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        lastKeyboardFrame = endFrame
        viewControllers.forEach {
            if let vc = $0 as? LoginViewController {
                vc.layoutForKeyboardFrame(endFrame)
            }
        }
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.pushViewController(viewController, animated: animated)
    }
    
    @discardableResult
    override func popViewController(animated: Bool) -> UIViewController? {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.popViewController(animated: animated)
    }
    
    @discardableResult
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]?  {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.popToViewController(viewController, animated: animated)
    }
    
    @discardableResult
    override func popToRootViewController(animated: Bool) -> [UIViewController]?  {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.popToRootViewController(animated: animated)
    }
    
    static func instance() -> UIViewController {
        return Storyboard.login.instantiateInitialViewController()!
    }
    
    private func updateBackButtonAlpha(animated: Bool) {
        let alpha: CGFloat
        if viewControllers.last is MobileNumberViewController || viewControllers.last is UsernameViewController {
            alpha = 0
        } else {
            alpha = 1
        }
        guard abs(backButton.alpha - alpha) > 0.1 else {
            return
        }
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.25)
        }
        backButton.alpha = alpha
        if animated {
            UIView.commitAnimations()
        }
    }
    
}
