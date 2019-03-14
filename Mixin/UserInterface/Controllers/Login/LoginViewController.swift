import UIKit
import SnapKit

class LoginViewController: UIViewController {
    
    struct LoginInfo {
        let callingCode: String
        let mobileNumber: String
        let fullNumber: String
        var verificationId: String?
    }
    
    let bottomWrapperView = BottomWrapperView()
    
    var continueButton: LoginContinueButton!
    var loginInfo: LoginInfo!
    var bottomWrapperViewBottomConstraint: Constraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(bottomWrapperView)
        bottomWrapperView.snp.makeConstraints { (make) in
            let inset = BottomWrapperView.defaultLayoutInset
            if #available(iOS 11.0, *) {
                bottomWrapperViewBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(inset.bottom).constraint
                make.leading.equalTo(view.safeAreaLayoutGuide.snp.leading).offset(inset.left)
                make.trailing.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-inset.right)
            } else {
                bottomWrapperViewBottomConstraint = make.bottom.equalTo(view.snp.bottom).offset(inset.bottom).constraint
                make.leading.equalTo(view.snp.leading).offset(inset.left)
                make.trailing.equalTo(view.snp.trailing).offset(-inset.right)
            }
        }
        continueButton = bottomWrapperView.continueButton
        continueButton.addTarget(self, action: #selector(continueAction(_:)), for: .touchUpInside)
        continueButton.isEnabled = false
        if let navigationController = navigationController as? LoginNavigationController {
//            layoutForKeyboardFrame(navigationController.lastKeyboardFrame)
        }
    }
    
    @objc func continueAction(_ sender: Any) {
        
    }
    
    func layoutForKeyboardFrame(_ keyboardFrame: CGRect) {
        guard let constraint = bottomWrapperViewBottomConstraint, let currentOffset = constraint.layoutConstraints.first?.constant else {
            return
        }
        let newOffset = keyboardFrame.origin.y - view.bounds.height - BottomWrapperView.defaultLayoutInset.bottom
        if abs(currentOffset - newOffset) > 60 || newOffset < currentOffset {
            constraint.update(offset: newOffset)
        }
    }
    
}
