import UIKit

class DeleteAccountAbortWindow: BottomSheetView {
    
    typealias CompletionHandler = (Bool) -> Void

    @IBOutlet weak var label: LineHeightLabel!
    @IBOutlet weak var continueButton: RoundedButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private weak var timer: Timer?
    private var completion: CompletionHandler?
    private var canDismiss = false
    private var countDown = 3

    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    override func dismissPopupControllerAnimated() {
        guard canDismiss else {
            return
        }
        super.dismissPopupControllerAnimated()
    }
    
    @IBAction func continueAction(_ sender: Any) {
        canDismiss = true
        completion?(false)
        dismissPopupControllerAnimated()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        canDismiss = true
        completion?(true)
        dismissPopupControllerAnimated()
    }
    
    class func instance() -> DeleteAccountAbortWindow {
        R.nib.deleteAccountAbortWindow(owner: self)!
    }
    
    func render(deactivatedAt: String, completion: @escaping CompletionHandler) {
        self.completion = completion
        let formatted = DateFormatter.deleteAccountFormatter.string(from: deactivatedAt.toUTCDate())
        label.text = R.string.localizable.landing_delete_content(formatted)
        continueButton.setTitle("\(R.string.localizable.continue())(\(self.countDown))", for: .normal)
        continueButton.isEnabled = false
        cancelButton.isEnabled = false
        cancelButton.setTitleColor(R.color.button_text_disabled()!, for: .normal)
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownAction), userInfo: nil, repeats: true)
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
