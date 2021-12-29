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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        
        pinField.delegate = self
        pinField.becomeFirstResponder()
        
        textLabel.font = .systemFont(ofSize: 16)
        textLabel.lineSpacing = 4
        textLabel.textColor = .title
        textLabel.detectLinks = false
        
        let date = DateFormatter.deleteAccountFormatter.string(from: Date())
        let text = R.string.localizable.setting_delete_account_confirm_hint(date)
        textLabel.text = text
        textLabel.delegate = self
        let linkRange = (text as NSString)
            .range(of: R.string.localizable.action_learn_more(), options: [.backwards, .caseInsensitive])
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
        dismissPopupControllerAnimated()
    }
    
    class func instance() -> DeleteAccountConfirmWindow {
        return R.nib.deleteAccountConfirmWindow(owner: self)!
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
    
    private func deleteAccount() {
        UserDatabase.current.erase()
        TaskDatabase.current.erase()
        //TODO: ‼️ logout desktop ? delete messages ?
        LoginManager.shared.logout(from: "DeleteAccount")
    }
    
}

extension DeleteAccountConfirmWindow: PinFieldDelegate {
    
    func inputFinished(pin: String) {
        //TODO: ‼️ new delete account api ?
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        AccountAPI.verify(pin: pin, completion: { [weak self] (result) in
            guard let self = self else {
                return
            }
            switch result {
            case .success:
                self.deleteAccount()
                hud.hide()
            case let .failure(error):
                hud.hide()
                self.pinField.clear()
                PINVerificationFailureHandler.handle(error: error) { (description) in
                    self.alert(description)
                }
            }
        })
    }
    
}

extension DeleteAccountConfirmWindow: CoreTextLabelDelegate {
    
    func coreTextLabel(_ label: CoreTextLabel, didSelectURL url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    func coreTextLabel(_ label: CoreTextLabel, didLongPressOnURL url: URL) {
        
    }
    
}
