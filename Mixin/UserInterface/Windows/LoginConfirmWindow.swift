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

        if let viewController = UIApplication.homeNavigationController?.viewControllers.first(where: { ($0 as? ContainerViewController)?.viewController is DesktopViewController }), let desktopVC =  (viewController as? ContainerViewController)?.viewController as? DesktopViewController {
            desktopVC.layoutForIsLoading(false)
            desktopVC.updateLabels(isDesktopLoggedIn: true)
        }
        UIApplication.homeNavigationController?.popViewController(animated: true)
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
