import UIKit
import SnapKit

struct ChangeNumberContext {
    var pin = ""
    var verificationId = ""
    var newNumber = ""
    var newNumberRepresentation = ""
}

class ChangeNumberViewController: UIViewController {

    static var lastKeyboardFrame = CGRect.zero

    let bottomWrapperView = BottomWrapperView()
    let bottomWrapperViewInset = BottomWrapperView.defaultLayoutInset

    var bottomWrapperBottomConstraint: Constraint!
    var context = ChangeNumberContext()
    
    var changeNumberNavigationController: ChangeNumberNavigationController? {
        return (navigationController as? ChangeNumberNavigationController)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(bottomWrapperView)
        bottomWrapperView.translatesAutoresizingMaskIntoConstraints = false
        bottomWrapperView.snp.makeConstraints { (make) in
            if #available(iOS 11.0, *) {
                make.leading.equalTo(self.view.safeAreaLayoutGuide.snp.leadingMargin).offset(bottomWrapperViewInset.left)
                make.trailing.equalTo(self.view.safeAreaLayoutGuide.snp.trailingMargin).offset(-bottomWrapperViewInset.right)
                bottomWrapperBottomConstraint = make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottomMargin).offset(-bottomWrapperViewInset.bottom).constraint
            } else {
                make.leading.equalTo(self.view.snp.leadingMargin).offset(bottomWrapperViewInset.left)
                make.trailing.equalTo(self.view.snp.trailingMargin).offset(-bottomWrapperViewInset.right)
                bottomWrapperBottomConstraint = make.bottom.equalTo(self.view.snp.bottomMargin).offset(-bottomWrapperViewInset.bottom).constraint
            }
        }
        updateBottomWrapperViewPosition(keyboardFrame: ChangeNumberViewController.lastKeyboardFrame)
        bottomWrapperView.continueButton.addTarget(self, action: #selector(continueAction(_:)), for: .touchUpInside)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(notification:)),
                                               name: .UIKeyboardWillChangeFrame,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func keyboardWillChangeFrame(notification: Notification) {
        let endFrame: CGRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
        ChangeNumberViewController.lastKeyboardFrame = endFrame
        updateBottomWrapperViewPosition(keyboardFrame: endFrame)
    }
    
    @objc func continueAction(_ sender: Any) {
        
    }

    private func updateBottomWrapperViewPosition(keyboardFrame: CGRect) {
        guard let currentOffset = bottomWrapperBottomConstraint.layoutConstraints.first?.constant else {
            return
        }
        let offset = -(UIScreen.main.bounds.height - keyboardFrame.origin.y + bottomWrapperViewInset.bottom)
        if abs(currentOffset - offset) > 60 || offset < currentOffset {
            bottomWrapperBottomConstraint.update(offset: offset)
        }
        view.layoutIfNeeded()
    }
    
}
