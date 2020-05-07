import UIKit

class VerifyPinNavigationController: LoneBackButtonNavigationController {
    
    let dismissButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dismissButton.tintColor = R.color.icon_tint()
        dismissButton.setImage(R.image.ic_title_close(), for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissAction(sender:)), for: .touchUpInside)
        view.addSubview(dismissButton)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.snp.makeConstraints { (make) in
            make.edges.equalTo(backButton)
        }
    }
    
    @objc func dismissAction(sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    override func updateBackButtonAlpha(animated: Bool) {
        let backButtonAlpha: CGFloat
        if viewControllers.last is VerifyPinViewController {
            backButtonAlpha = 0
        } else {
            backButtonAlpha = 1
        }
        let dismissButtonAlpha = 1 - backButtonAlpha
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.25)
        }
        backButton.alpha = backButtonAlpha
        dismissButton.alpha = dismissButtonAlpha
        if animated {
            UIView.commitAnimations()
        }
    }
    
}
