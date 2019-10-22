import UIKit

final class EmergencyTipsViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    var onNext: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.set(font: .systemFont(ofSize: 17, weight: .semibold), adjustForContentSize: true)
    }
    
    class func instance() -> EmergencyTipsViewController {
        let vc = R.storyboard.setting.emergency_tips()!
        vc.transitioningDelegate = PopupPresentationManager.shared
        vc.modalPresentationStyle = .custom
        return vc
    }
    
    @IBAction func nextAction(_ sender: Any) {
        dismiss(animated: true) {
            self.onNext?()
        }
    }
    
}
