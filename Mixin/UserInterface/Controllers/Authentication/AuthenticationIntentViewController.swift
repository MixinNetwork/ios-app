import UIKit
import MixinServices

enum AuthenticationIntentSubtitleIcon {
    case app(App)
    case url(URL)
}

struct AuthenticationIntentOptions: OptionSet {
    
    let rawValue: Int
    
    static let allowsBiometricAuthentication = AuthenticationIntentOptions(rawValue: 1 << 0)
    static let becomesFirstResponderOnAppear = AuthenticationIntentOptions(rawValue: 1 << 1)
    static let unskippable = AuthenticationIntentOptions(rawValue: 1 << 2)
    static let blurBackground = AuthenticationIntentOptions(rawValue: 1 << 3)
    
}

protocol AuthenticationIntentViewController: UIViewController {
    
    var intentTitle: String { get }
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? { get }
    var intentSubtitle: String { get }
    var options: AuthenticationIntentOptions { get }
    
    var authenticationViewController: AuthenticationViewController? { get }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    )
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController)
    
}

extension AuthenticationIntentViewController {
    
    var authenticationViewController: AuthenticationViewController? {
        parent as? AuthenticationViewController
    }
    
}
