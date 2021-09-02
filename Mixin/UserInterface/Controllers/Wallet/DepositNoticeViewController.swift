import UIKit

class DepositNoticeViewController: UIViewController {
    
    @IBOutlet weak var tipsLabel: UILabel!
    
    var dismissCompletion: (() -> Void)?
    
    convenience init(tips: String) {
        self.init(nib: R.nib.depositNoticeView)
        loadViewIfNeeded()
        tipsLabel.text = tips
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
        modalTransitionStyle = .crossDissolve
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: dismissCompletion)
    }
    
}
