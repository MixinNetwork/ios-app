import UIKit

final class AbortAccountDeletionViewController: UIViewController {
    
    @IBOutlet weak var label: LineHeightLabel!
    
    var context: LoginContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let date: Date
        if let deactivatedAt = context.deactivatedAt {
            date = deactivatedAt.toUTCDate()
        } else {
            date = Date()
        }
        let formatted = DateFormatter.deleteAccountFormatter.string(from: date)
        label.text = R.string.localizable.abort_account_deletion_hint(formatted)
    }
    
    @IBAction func continueAction(_ sender: Any) {
        let vc = PhoneNumberLoginVerificationCodeViewController()
        vc.context = context
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
}
