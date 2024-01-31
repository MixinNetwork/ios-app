import UIKit

final class EmergencyTipsViewController: UIViewController {

    var onNext: (() -> Void)?
    
    class func instance() -> EmergencyTipsViewController {
        let vc = R.storyboard.setting.emergency_tips()!
        vc.transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        vc.modalPresentationStyle = .custom
        return vc
    }
    
    @IBAction func nextAction(_ sender: Any) {
        dismiss(animated: true) {
            self.onNext?()
        }
    }
    
}
