import UIKit

class LoginConfirmWindow: BottomSheetView {

    @IBOutlet weak var loginButton: RoundedButton!

    private var uuid: String!
    private var publicKey: String!

    @IBAction func loginAction(_ sender: Any) {
        guard !loginButton.isBusy else {
            return
        }
        loginButton.isBusy = true
        ProvisionManager.updateProvision(uuid: uuid, base64EncodedPublicKey: publicKey, completion: { [weak self](success) in
            self?.loginButton.isBusy = false
            if success {
                self?.loginSuccessAction()
            }
        })
    }

    func loginSuccessAction() {
        dismissView()
        showHud(style: .notification, text: Localized.TOAST_LOGINED)

        if let viewController = UIApplication.rootNavigationController()?.viewControllers.first(where: { ($0 as? ContainerViewController)?.viewController is DesktopViewController }), let desktopVC =  (viewController as? ContainerViewController)?.viewController as? DesktopViewController {
            desktopVC.layoutForIsLoading(false)
            desktopVC.updateLabels(isDesktopLoggedIn: true)
        }
        UIApplication.rootNavigationController()?.popViewController(animated: true)
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
