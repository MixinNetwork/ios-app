import UIKit

protocol AuthenticationIntentViewController: UIViewController {
    
    var intentTitle: String { get }
    var intentSubtitleIconURL: URL? { get }
    var intentSubtitle: String { get }
    var isBiometryAuthAllowed: Bool { get }
    var inputPINOnAppear: Bool { get }
    
    var authenticationViewController: AuthenticationViewController? { get }
    
    func authenticationViewController(_ controller: AuthenticationViewController, didInput pin: String, completion: @escaping @MainActor (Error?) -> Void)
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController)
    
}

extension AuthenticationIntentViewController {
    
    var authenticationViewController: AuthenticationViewController? {
        parent as? AuthenticationViewController
    }
    
}
