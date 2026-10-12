import UIKit
import MixinServices

final class AuthorizationWindow: UIViewController {
    
    @IBOutlet weak var scopePreviewView: AuthorizationScopePreviewView!
    @IBOutlet weak var scopeConfirmationView: AuthorizationScopeConfirmationView!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var appNumberLabel: UILabel!
    
    @IBOutlet weak var avatarWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var showScopePreviewViewConstraint: NSLayoutConstraint!
    @IBOutlet weak var showScopeConfirmationViewConstraint: NSLayoutConstraint!
    
    private var dataSource: AuthorizationScopeDataSource!
    private let authInfo: AuthorizationResponse
    private var loginSuccess = false
    
    init(authInfo: AuthorizationResponse) {
        self.authInfo = authInfo
        let nib = R.nib.authorizationWindow
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        avatarImageView.setImage(app: authInfo.app)
        setupLabels()
        dataSource = AuthorizationScopeDataSource(response: authInfo)
        scopePreviewView.delegate = self
        scopePreviewView.dataSource = dataSource
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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
    
    @IBAction func backAction(_ sender: Any) {
        dismiss(animated: true)
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

extension AuthorizationWindow: AuthorizationScopePreviewViewDelegate {
    
    func authorizationScopePreviewViewDidReviewScopes(_ controller: AuthorizationScopePreviewView) {
        scopeConfirmationView.dataSource = dataSource
        scopeConfirmationView.delegate = self
        scopeConfirmationView.resetInput()
        showScopePreviewViewConstraint.priority = .defaultLow
        showScopeConfirmationViewConstraint.priority = .defaultHigh
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            self.scopePreviewView.isHidden = true
            self.scopeConfirmationView.isHidden = false
        } completion: { _ in
            self.scopeConfirmationView.tableView.flashScrollIndicators()
        }
    }
    
}

extension AuthorizationWindow: AuthorizationScopeConfirmationViewDelegate {
    
    func authorizationScopeConfirmationView(_ view: AuthorizationScopeConfirmationView, didConfirmWith pin: String) {
        let scopes = dataSource.selectedScopes.map(\.rawValue)
        Logger.general.debug(category: "Authorization", message: "Will authorize scopes: \(scopes)")
        AuthorizeAPI.authorize(authorizationId: authInfo.authorizationId, scopes: scopes, pin: pin) { [weak self] result in
            guard let self = self else {
                return
            }
            view.loadingIndicator.stopAnimating()
            switch result {
            case let .success(response):
                AppGroupUserDefaults.Wallet.lastPINVerifiedDate = Date()
                self.loginSuccess = true
                showAutoHiddenHud(style: .notification, text: R.string.localizable.authorized())
                self.dismiss(animated: true)
                if UIApplication.shared.homeNavigationController?.viewControllers.last is QRCodeScannerViewController {
                    UIApplication.shared.homeNavigationController?.popViewController(animated: true)
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
