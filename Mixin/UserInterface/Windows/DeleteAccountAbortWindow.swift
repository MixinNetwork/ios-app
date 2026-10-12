import UIKit
import MixinServices

final class DeleteAccountAbortWindow: UIViewController {
    
    typealias CompletionHandler = (Bool) -> Void

    @IBOutlet weak var label: LineHeightLabel!
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private let presentationManager = PopupPresentationManager()
    private weak var timer: Timer?
    private let completion: CompletionHandler?
    private let deactivation: Deactivation
    private var canDismiss = false
    private var countDown = 3

    init(deactivation: Deactivation, completion: CompletionHandler? = nil) {
        self.deactivation = deactivation
        self.completion = completion
        let nib = R.nib.deleteAccountAbortWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = presentationManager
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let requestedAt = DateFormatter.deleteAccount.string(from: deactivation.requestedAt)
        let effectiveAt = DateFormatter.deleteAccount.string(from: deactivation.effectiveAt)
        label.text = R.string.localizable.landing_delete_content(requestedAt, effectiveAt)
        continueButton.setTitle("\(R.string.localizable.continue())(\(self.countDown))", for: .normal)
        continueButton.isEnabled = false
        cancelButton.isEnabled = false
        cancelButton.setTitleColor(R.color.button_text_disabled()!, for: .normal)
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownAction), userInfo: nil, repeats: true)
    }
    
    @IBAction func continueAction(_ sender: Any) {
        canDismiss = true
        let completion = self.completion
        dismiss(animated: true) {
            completion?(false)
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        canDismiss = true
        let completion = self.completion
        dismiss(animated: true) {
            completion?(true)
        }
    }
    
    @objc private func countDownAction() {
        countDown -= 1
        if countDown <= 0 {
            timer?.invalidate()
            timer = nil
            UIView.performWithoutAnimation {
                self.continueButton.isEnabled = true
                self.continueButton.setTitle(R.string.localizable.continue(), for: .normal)
                self.continueButton.layoutIfNeeded()
                self.cancelButton.isEnabled = true
                self.cancelButton.setTitleColor(.theme, for: .normal)
            }
        } else {
            UIView.performWithoutAnimation {
                self.continueButton.setTitle("\(R.string.localizable.continue())(\(self.countDown))", for: .normal)
                self.continueButton.layoutIfNeeded()
            }
        }
    }
    
}
