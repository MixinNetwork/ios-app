import UIKit

class EmergencyTipsViewController: UIViewController {
    
    @IBOutlet weak var descriptionTextView: IntroTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let text = R.string.localizable.emergency_tip2()
        descriptionTextView.text = text
        let range = (text as NSString).range(of: R.string.localizable.emergency_tip2_link())
        guard range.location != NSNotFound && range.length != 0 else {
            return
        }
        guard let str = descriptionTextView.attributedText?.mutableCopy() as? NSMutableAttributedString else {
            return
        }
        let url = URL(string: "https://mixinmessenger.zendesk.com/hc/articles/360029154692")!
        str.addAttribute(.link, value: url, range: range)
        descriptionTextView.attributedText = str
    }
    
    @IBAction func nextAction(_ sender: Any) {
        weak var navigationController: UINavigationController?
        if let controller = presentingViewController as? UINavigationController {
            navigationController = controller
        } else if let controller = presentingViewController?.navigationController {
            navigationController = controller
        }
        dismiss(animated: true) {
            if let account = AccountAPI.shared.account, account.has_pin {
                let vc = EmergencyContactVerifyPinViewController()
                let nav = VerifyPinNavigationController(rootViewController: vc)
                navigationController?.present(nav, animated: true, completion: nil)
            } else {
                let vc = WalletPasswordViewController.instance(dismissTarget: .setEmergencyContact)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
}
