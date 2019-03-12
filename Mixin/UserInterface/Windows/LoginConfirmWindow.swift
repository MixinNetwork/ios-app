import UIKit

class LoginConfirmWindow: BottomSheetView {

    @IBOutlet weak var loginButton: RoundedButton!

    private var uuid: String!
    private var publicKey: String!

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged), name: .UserSessionDidChange, object: nil)
    }

    @objc func sessionChanged() {
        guard loginButton.isBusy else {
            return
        }

        loginButton.isBusy = false
        dismissView()
        UIApplication.rootNavigationController()?.showHud(style: .notification, text: Localized.TOAST_LOGINED)
        UIApplication.rootNavigationController()?.popViewController(animated: true)
    }

    @IBAction func loginAction(_ sender: Any) {
        guard !loginButton.isBusy else {
            return
        }
        loginButton.isBusy = true
        ProvisionManager.updateProvision(uuid: uuid, base64EncodedPublicKey: publicKey, completion: { _ in

        })
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissView()
    }

    class func instance(uuid: String, publicKey: String) -> LoginConfirmWindow {
        let window = Bundle.main.loadNibNamed("LoginConfirmWindow", owner: nil, options: nil)?.first as! LoginConfirmWindow
        window.uuid = uuid
        window.publicKey = publicKey
        return window
    }
}
