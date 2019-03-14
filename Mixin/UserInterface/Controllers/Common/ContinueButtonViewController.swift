import UIKit
import SnapKit

class ContinueButtonViewController: UIViewController {
    
    let continueButton = BusyButton()
    
    var continueButtonBottomConstraint: Constraint!
    var viewHasAppeared = false
    
    private let continueButtonLength: CGFloat = 44
    private let continueButtonMargin: CGFloat = 20
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        continueButton.isHidden = true
        continueButton.busyIndicator.style = .white
        continueButton.busyIndicator.backgroundColor = .theme
        continueButton.busyIndicator.clipsToBounds = true
        continueButton.busyIndicator.layer.cornerRadius = continueButtonLength / 2
        continueButton.setImage(R.image.ic_action_next(), for: .normal)
        continueButton.backgroundColor = .theme
        continueButton.clipsToBounds = true
        continueButton.layer.cornerRadius = continueButtonLength / 2
        continueButton.addTarget(self, action: #selector(continueAction(_:)), for: .touchUpInside)
        view.addSubview(continueButton)
        continueButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(continueButtonLength)
            make.trailing.equalToSuperview().offset(-continueButtonMargin)
            continueButtonBottomConstraint = make.bottom.equalToSuperview().constraint
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewHasAppeared = true
    }
    
    @objc func continueAction(_ sender: Any) {
        
    }
    
    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let work = {
            let offset = self.view.frame.height
                - endFrame.origin.y
                + self.continueButtonMargin
            self.continueButtonBottomConstraint.update(offset: -offset)
            self.view.layoutIfNeeded()
        }
        if viewHasAppeared {
            work()
        } else {
            UIView.performWithoutAnimation(work)
        }
    }
    
}
