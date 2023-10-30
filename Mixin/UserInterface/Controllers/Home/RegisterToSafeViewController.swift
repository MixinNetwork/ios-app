import UIKit
import MixinServices

final class RegisterToSafeViewController: UIViewController {
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.backgroundColor = .background
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeEdgesEqualToSuperview()
        reloadAccount()
    }
    
    func reloadAccount() {
        guard LoginManager.shared.isLoggedIn else {
            return
        }
        AccountAPI.me { result in
            switch result {
            case let .success(account):
                LoginManager.shared.setAccount(account, updateUserTable: false)
                Task {
                    if let context = try await TIP.checkCounter(with: account) {
                        await MainActor.run {
                            self.authenticationViewController?.presentingViewController?.dismiss(animated: true) {
                                let intro = TIPIntroViewController(context: context)
                                let navigation = TIPNavigationViewController(intro: intro, destination: nil)
                                UIApplication.homeNavigationController?.present(navigation, animated: true)
                            }
                        }
                    } else {
                        await MainActor.run {
                            switch TIP.Status(account: account) {
                            case .ready:
                                if account.hasSafe {
                                    self.authenticationViewController?.presentingViewController?.dismiss(animated: true)
                                } else {
                                    self.activityIndicator.removeFromSuperview()
                                    self.authenticationViewController?.beginPINInputting()
                                }
                            case .needsMigrate:
                                self.authenticationViewController?.presentingViewController?.dismiss(animated: true) {
                                    let tip = TIPNavigationViewController(intent: .migrate, destination: nil)
                                    UIApplication.homeNavigationController?.navigationController?.present(tip, animated: true)
                                }
                            case .needsInitialize:
                                self.authenticationViewController?.presentingViewController?.dismiss(animated: true) {
                                    let tip = TIPNavigationViewController(intent: .create, destination: nil)
                                    UIApplication.homeNavigationController?.navigationController?.present(tip, animated: true)
                                }
                            case .unknown:
                                break
                            }
                        }
                    }
                }
            case .failure(.unauthorized):
                break
            case let .failure(error):
                Logger.general.warn(category: "RegisterToSafe", message: "Failed to load account: \(error)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: self.reloadAccount)
            }
        }
    }
    
}

extension RegisterToSafeViewController: AuthenticationIntentViewController {
    
    var intentTitle: String {
        "Register to Safe"
    }
    
    var intentSubtitleIconURL: AuthenticationIntentSubtitleIcon? {
        nil
    }
    
    var intentSubtitle: String {
        "Input PIN to register"
    }
    
    var options: AuthenticationIntentOptions {
        [.allowsBiometricAuthentication, .unskippable]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        Task {
            do {
                try await TIP.registerToSafe(pin: pin)
                await MainActor.run {
                    completion(.success)
                    self.authenticationViewController?.presentingViewController?.dismiss(animated: true)
                    ConcurrentJobQueue.shared.addJob(job: RefreshAccountJob())
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error: error, allowsRetrying: true))
                }
            }
        }
    }
    
    func authenticationViewControllerWillDismiss(_ controller: AuthenticationViewController) {
        
    }
    
}
