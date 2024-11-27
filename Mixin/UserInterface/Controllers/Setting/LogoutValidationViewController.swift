import UIKit
import MixinServices

final class LogoutValidationViewController: UIViewController {
    
    @IBOutlet weak var textView: IntroTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.textAlignment = .center
        textView.font = .preferredFont(forTextStyle: .callout)
        textView.textColor = R.color.text()
        textView.text = R.string.localizable.logout_description()
    }
    
}

extension LogoutValidationViewController: AuthenticationIntent {
    
    var intentTitle: String {
        R.string.localizable.logout_title()
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
        [.neverRequestAddBiometricAuthentication, .becomesFirstResponderOnAppear, .viewUnderPINField]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        guard let sessionID = LoginManager.shared.account?.sessionID else {
            return
        }
        AccountAPI.verify(pin: pin) { result in
            switch result {
            case .success:
                AccountAPI.logoutSession(sessionId: sessionID) { result in
                    switch result {
                    case .success:
                        completion(.success)
                        controller.presentingViewController?.dismiss(animated: true) {
                            LoginManager.shared.logout(reason: "User")
                        }
                    case .failure(let error):
                        completion(.failure(error: error, retry: .inputPINAgain))
                    }
                }
            case .failure(let error):
                completion(.failure(error: error, retry: .inputPINAgain))
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
