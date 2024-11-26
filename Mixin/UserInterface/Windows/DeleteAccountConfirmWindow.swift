import UIKit
import MixinServices

final class DeleteAccountConfirmWindow: BottomSheetView {
    
    @IBOutlet weak var pinField: PinField!
    @IBOutlet weak var textLabel: TextLabel!
    
    @IBOutlet weak var textLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLabelTrailingConstraint: NSLayoutConstraint!
    
    private var lastViewWidth: CGFloat = 0
    private var verificationID: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        
        pinField.delegate = self
        pinField.becomeFirstResponder()
        
        textLabel.font = .preferredFont(forTextStyle: .callout)
        textLabel.lineSpacing = 4
        textLabel.textColor = R.color.text()!
        textLabel.detectLinks = false
        
        let thirtyDaysLater = Date().addingTimeInterval(30 * .day)
        let date = DateFormatter.deleteAccount.string(from: thirtyDaysLater)
        let hint = R.string.localizable.setting_delete_account_pin_content(date)
        textLabel.text = hint
        textLabel.delegate = self
        let linkRange = (hint as NSString)
            .range(of: R.string.localizable.learn_more(), options: [.backwards, .caseInsensitive])
        if linkRange.location != NSNotFound && linkRange.length != 0 {
            textLabel.linkColor = .theme
            textLabel.additionalLinksMap = [linkRange: URL.deleteAccount]
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width != lastViewWidth else {
            return
        }
        let labelWidth = bounds.width
            - textLabelLeadingConstraint.constant
            - textLabelTrailingConstraint.constant
        let sizeToFitLabel = CGSize(width: labelWidth, height: UIView.layoutFittingExpandedSize.height)
        textLabelHeightConstraint.constant = textLabel.sizeThatFits(sizeToFitLabel).height
        lastViewWidth = bounds.width
    }
    
    @IBAction func closeAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
    class func instance(verificationID: String?) -> DeleteAccountConfirmWindow {
        let window = R.nib.deleteAccountConfirmWindow(withOwner: self)!
        window.verificationID = verificationID
        return window
    }
    
}

extension DeleteAccountConfirmWindow {
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let windowHeight = AppDelegate.current.mainWindow.bounds.height
        textLabelBottomConstraint.constant = windowHeight - endFrame.origin.y + 60
        layoutIfNeeded()
    }
    
}

extension DeleteAccountConfirmWindow: PinFieldDelegate {
    
    func inputFinished(pin: String) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        AccountAPI.deactiveAccount(pin: pin, verificationID: verificationID) { [weak self] (result) in
            hud.hide()
            guard let weakSelf = self else {
                return
            }
            switch result {
            case .success:
                LoginManager.shared.logout(reason: "DeleteAccount")
            case let .failure(error):
                weakSelf.pinField.clear()
                PINVerificationFailureHandler.handle(error: error) { [weak self] (description) in
                    self?.alert(description, cancelHandler: { _ in
                        self?.pinField.becomeFirstResponder()
                    })
                }
            }
        }
    }
    
}

extension DeleteAccountConfirmWindow: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }
    
}
