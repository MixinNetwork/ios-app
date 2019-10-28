import UIKit

class LoginConfirmWindow: BottomSheetView {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var loginButton: RoundedButton!

    private var id: String!
    private var publicKey: String!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 17, weight: .semibold), adjustForContentSize: true)
    }
    
    @IBAction func loginAction(_ sender: Any) {
        guard !loginButton.isBusy else {
            return
        }
        loginButton.isBusy = true
        ProvisionManager.updateProvision(id: id, base64EncodedPublicKey: publicKey, completion: { [weak self](success) in
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
