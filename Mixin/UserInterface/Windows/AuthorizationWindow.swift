import Foundation
import MixinServices
import SDWebImage

class AuthorizationWindow: BottomSheetView {
    
    @IBOutlet weak var scopeDetailView: AuthorizationScopeDetailView!
    @IBOutlet weak var scopeConfirmationView: AuthorizationScopeConfirmationView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var appNumberLabel: UILabel!
    
    @IBOutlet weak var avatarWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackViewWidthConstraint: NSLayoutConstraint!
    
    private var scopeHandler: AuthorizationScopeHandler!
    private var authInfo: AuthorizationResponse!
    private var loginSuccess = false
    
    override func dismissPopupController(animated: Bool) {
        super.dismissPopupController(animated: animated)
        guard !loginSuccess else {
            return
        }
        AuthorizeAPI.authorize(authorizationId: authInfo.authorizationId, scopes: [], pin: nil) { (result) in
            switch result {
            case let .success(response):
                UIApplication.shared.tryOpenThirdApp(response: response)
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    class func instance() -> AuthorizationWindow {
        R.nib.authorizationWindow(owner: self)!
    }
    
    func render(authInfo: AuthorizationResponse) -> AuthorizationWindow {
        self.authInfo = authInfo
        avatarImageView.setImage(app: authInfo.app)
        setupLabels()
        scopeHandler = AuthorizationScopeHandler(scopeInfos: Scope.getCompleteScopeInfos(authInfo: authInfo))
        scopeDetailView.delegate = self
        scopeDetailView.render(with: scopeHandler)
        return self
    }
    
    @IBAction func backAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        DispatchQueue.main.async(execute: setupLabels)
    }
    
    private func setupLabels() {
        nameLabel.text = "\(authInfo.app.name) (\(authInfo.app.appNumber))"
        let avaliableWidth = stackViewWidthConstraint.constant - avatarWidthConstraint.constant - stackView.spacing
        let sizeToFitLabel = CGSize(width: UIView.layoutFittingExpandedSize.width, height: nameLabel.bounds.height)
        let nameLabelWidth = nameLabel.sizeThatFits(sizeToFitLabel).width
        if nameLabelWidth > avaliableWidth {
            nameLabel.text = "\(authInfo.app.name)"
            appNumberLabel.text = "(\(authInfo.app.appNumber))"
            appNumberLabel.isHidden = false
        } else {
            appNumberLabel.text = ""
            appNumberLabel.isHidden = true
        }
    }
    
}

extension AuthorizationWindow: AuthorizationScopeDetailViewDelegate {
    
    func authorizationScopeDetailViewDidReviewScopes(_ controller: AuthorizationScopeDetailView) {
        scopeConfirmationView.delegate = self
        scopeConfirmationView.render(with: scopeHandler)
        UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.scopeDetailView.isHidden = true
            self.scopeConfirmationView.isHidden = false
        })
    }
    
}

extension AuthorizationWindow: AuthorizationScopeConfirmationViewDelegate {
    
    func authorizationScopeConfirmationView(_ view: AuthorizationScopeConfirmationView, validate pin: String) {
        let scopes = scopeHandler.selectedItems.map(\.scope)
        AuthorizeAPI.authorize(authorizationId: authInfo.authorizationId, scopes: scopes, pin: pin) { [weak self] result in
            guard let self = self else {
                return
            }
            view.loadingIndicator.stopAnimating()
            switch result {
            case let .success(response):
                AppGroupUserDefaults.Wallet.lastPinVerifiedDate = Date()
                self.loginSuccess = true
                showAutoHiddenHud(style: .notification, text: R.string.localizable.authorized())
                self.dismissPopupController(animated: true)
                if UIApplication.homeNavigationController?.viewControllers.last is CameraViewController {
                    UIApplication.homeNavigationController?.popViewController(animated: true)
                }
                UIApplication.shared.tryOpenThirdApp(response: response)
            case let .failure(error):
                PINVerificationFailureHandler.handle(error: error) { description in
                    self.alert(description)
                }
                view.resetInput()
            }
        }
    }
    
}

private extension UIApplication {
    
    func tryOpenThirdApp(response: AuthorizationResponse) {
        let callback = response.app.redirectUri
        guard
            !callback.isEmpty,
            let url = URL(string: callback),
            let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https",
            var components = URLComponents(string: callback)
        else {
            return
        }
        if components.queryItems == nil {
            components.queryItems = []
        }
        if response.authorizationCode.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "error", value: "access_denied"))
        } else {
            components.queryItems?.append(URLQueryItem(name: "code", value: response.authorizationCode))
        }
        guard let targetUrl = components.url else {
            return
        }
        UIApplication.shared.open(targetUrl, options: [:], completionHandler: nil)
    }
    
}
