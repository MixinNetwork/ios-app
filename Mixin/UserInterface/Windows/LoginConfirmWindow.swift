import UIKit
import MixinServices

class LoginConfirmWindow: BottomSheetView {

    @IBOutlet weak var loginButton: RoundedButton!

    private var id: String!
    private var publicKey: String!

    @IBAction func loginAction(_ sender: Any) {
        guard !loginButton.isBusy else {
            return
        }
        loginButton.isBusy = true
        LoginManager.shared.updateProvision(id: id, base64EncodedPublicKey: publicKey, completion: { [weak self](success) in
            self?.loginButton.isBusy = false
            if success {
                self?.loginSuccessAction()
            }
        })
    }

    func loginSuccessAction() {
        dismissView()
        showAutoHiddenHud(style: .notification, text: Localized.TOAST_LOGINED)
    }


    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }

    class func instance(id: String, publicKey: String) -> LoginConfirmWindow {
        let window = Bundle.main.loadNibNamed("LoginConfirmWindow", owner: nil, options: nil)?.first as! LoginConfirmWindow
        window.id = id
        window.publicKey = publicKey
        return window
    }
}
