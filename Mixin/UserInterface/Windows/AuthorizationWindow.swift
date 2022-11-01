import Foundation
import MixinServices
import SDWebImage

class AuthorizationWindow: BottomSheetView {
    
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var scopeDetailView: AuthorizationScopeDetailView!
    @IBOutlet weak var scopeConfirmationView: AuthorizationScopeConfirmationView!
    
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
        SDWebImageManager.shared.loadImage(with: URL(string: authInfo.app.iconUrl), options: [], progress: nil, completed: { (image, _, error, _, _, _) in
            let avatar: UIImage?
            if error == nil, let image = image {
                avatar = image
            } else {
                avatar = R.image.ic_place_holder()
            }
            let avatarAttachment = NSTextAttachment()
            avatarAttachment.image = avatar
            avatarAttachment.bounds = CGRect(x: 0, y: -3, width: 16, height: 16)
            
            let padding = NSTextAttachment()
            padding.bounds = CGRect(x: 0, y: 0, width: 4, height: 0)
            
            let fullString = NSMutableAttributedString(string: "")
            fullString.append(NSAttributedString(attachment: avatarAttachment))
            fullString.append(NSAttributedString(attachment: padding))
            fullString.append(NSAttributedString(string: "\(authInfo.app.name) (\(authInfo.app.appNumber))"))
            
            DispatchQueue.main.async {
                self.descriptionLabel.attributedText = fullString
            }
        })
        scopeHandler = AuthorizationScopeHandler(scopeInfos: Scope.getCompleteScopeInfos(authInfo: authInfo))
        scopeDetailView.delegate = self
        scopeDetailView.render(with: scopeHandler)
        scopeConfirmationView.delegate = self
        return self
    }
    
    @IBAction func backAction(_ sender: Any) {
        dismissPopupController(animated: true)
    }
    
}

extension AuthorizationWindow: AuthorizationScopeDetailViewDelegate {
    
    func authorizationScopeDetailViewDidReviewScopes(_ controller: AuthorizationScopeDetailView) {
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
