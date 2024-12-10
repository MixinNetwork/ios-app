import UIKit
import MixinServices

final class DesktopSessionValidationViewController: UIViewController {
    
    enum Intent {
        case login(id: String, publicKey: String)
        case logout(sessionID: String)
    }
    
    @IBOutlet weak var label: UILabel!
    
    var onSuccess: (() -> Void)?
    
    private let intent: Intent
    
    init(intent: Intent) {
        self.intent = intent
        let nib = R.nib.desktopSessionValidationView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        label.text = switch intent {
        case .login:
            R.string.localizable.desktop_login()
        case .logout:
            R.string.localizable.desktop_logout()
        }
    }
    
}

extension DesktopSessionValidationViewController: AuthenticationIntent {
    
    var intentTitle: String {
        ""
    }
    
    var intentTitleIcon: UIImage? {
        nil
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        ""
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .becomesFirstResponderOnAppear, .neverRequestAddBiometricAuthentication]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        switch intent {
        case let .login(id, publicKey):
            guard let identityKeyPair = try? PreKeyUtil.getIdentityKeyPair(), let account = LoginManager.shared.account else {
                return
            }
            ProvisioningAPI.code { (response) in
                switch response {
                case .success(let response):
                    let message = ProvisionMessage(
                        identityKeyPublic: identityKeyPair.publicKey,
                        identityKeyPrivate: identityKeyPair.privateKey,
                        userId: account.userID,
                        sessionId: account.sessionID,
                        provisioningCode: response.code
                    )
                    do {
                        let secretData = try message.encrypt(with: publicKey)
                        let secret = secretData.base64EncodedString()
                        ProvisioningAPI.update(id: id, secret: secret, pin: pin, completion: { (result) in
                            switch result {
                            case .success:
                                completion(.success)
                                self.presentingViewController?.dismiss(animated: true)
                                self.onSuccess?()
                            case .failure(let error):
                                completion(.failure(error: error, retry: .notAllowed))
                            }
                        })
                    } catch {
                        completion(.failure(error: error, retry: .notAllowed))
                    }
                case .failure(let error):
                    completion(.failure(error: error, retry: .notAllowed))
                }
            }
        case let .logout(sessionID):
            AccountAPI.logout(sessionID: sessionID, pin: pin) { result in
                switch result {
                case .success:
                    completion(.success)
                    self.presentingViewController?.dismiss(animated: true)
                    self.onSuccess?()
                case .failure(let error):
                    completion(.failure(error: error, retry: .notAllowed))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
