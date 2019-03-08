import UIKit

class ChangeNumberNavigationController: UINavigationController {

    let backButton = UIButton()
    let dismissButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        backButton.setImage(R.image.ic_title_back(), for: .normal)
        backButton.addTarget(self, action: #selector(backAction(sender:)), for: .touchUpInside)
        backButton.alpha = 0
        dismissButton.setImage(R.image.ic_title_close(), for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissAction(sender:)), for: .touchUpInside)
        for button in [backButton, dismissButton] {
            view.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.snp.makeConstraints { (make) in
                make.width.height.equalTo(44)
                if #available(iOS 11.0, *) {
                    make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
                    make.leading.equalTo(self.view.safeAreaLayoutGuide.snp.leadingMargin).offset(10)
                } else {
                    make.top.equalTo(self.topLayoutGuide.snp.bottom)
                    make.leading.equalTo(self.view.snp.leading).offset(10)
                }
            }
        }
    }

    @objc func dismissAction(sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func backAction(sender: Any) {
        popViewController(animated: true)
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        defer {
            updateButtonsAlpha(animated: animated)
        }
        return super.pushViewController(viewController, animated: animated)
    }
    
    @discardableResult
    override func popViewController(animated: Bool) -> UIViewController? {
        defer {
            updateButtonsAlpha(animated: animated)
        }
        return super.popViewController(animated: animated)
    }
    
    @discardableResult
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]?  {
        defer {
            updateButtonsAlpha(animated: animated)
        }
        return super.popToViewController(viewController, animated: animated)
    }
    
    @discardableResult
    override func popToRootViewController(animated: Bool) -> [UIViewController]?  {
        defer {
            updateButtonsAlpha(animated: animated)
        }
        return super.popToRootViewController(animated: animated)
    }
    
    static func instance() -> UIViewController {
        return Storyboard.contact.instantiateViewController(withIdentifier: "change_number_navigation")
    }
    
    @objc func continueAction(_ sender: Any) {
        (topViewController as? ChangeNumberViewController)?.continueAction(sender)
    }
    
    private func updateButtonsAlpha(animated: Bool) {
        let backButtonAlpha: CGFloat
        if viewControllers.last is ChangeNumberVerifyPINViewController {
            backButtonAlpha = 0
        } else {
            backButtonAlpha = 1
        }
        let dismissButtonAlpha = 1 - backButtonAlpha
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.25)
        }
        if abs(backButton.alpha - backButtonAlpha) > 0.1 {
            backButton.alpha = backButtonAlpha
        }
        if abs(dismissButton.alpha - dismissButtonAlpha) > 0.1 {
            dismissButton.alpha = dismissButtonAlpha
        }
        if animated {
            UIView.commitAnimations()
        }
    }
    
}
