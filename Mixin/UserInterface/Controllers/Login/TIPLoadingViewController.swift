import UIKit
import MixinServices

final class TIPLoadingViewController: LoginLoadingViewController {
    
    private let freshAccount: Account?
    
    private weak var retryButton: UIButton?
    
    init(freshAccount: Account?) {
        self.freshAccount = freshAccount
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reload(self)
    }
    
    @objc private func reload(_ sender: Any) {
        activityIndicator.startAnimating()
        descriptionLabel.text = R.string.localizable.initializing()
        descriptionLabel.textColor = R.color.text_tertiary()
        retryButton?.removeFromSuperview()
        Task {
            do {
                let account: Account
                if let a = self.freshAccount {
                    account = a
                } else {
                    account = try await AccountAPI.me()
                }
                let context = try await TIP.checkCounter(with: account)
                await MainActor.run {
                    if let context {
                        let intro = TIPIntroViewController(context: context)
                        let navigation = TIPNavigationController(intro: intro)
                        AppDelegate.current.mainWindow.rootViewController = navigation
                    } else {
                        let validation = LoginPINValidationViewController(account: account)
                        let navigation = GeneralAppearanceNavigationController(rootViewController: validation)
                        AppDelegate.current.mainWindow.rootViewController = navigation
                    }
                }
            } catch {
                await MainActor.run {
                    activityIndicator.stopAnimating()
                    descriptionLabel.text = error.localizedDescription
                    descriptionLabel.textColor = R.color.error_red()
                    let button = StyledButton()
                    button.setTitle(R.string.localizable.retry(), for: .normal)
                    button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
                    button.style = .filled
                    button.addTarget(self, action: #selector(reload(_:)), for: .touchUpInside)
                    button.applyDefaultContentInsets()
                    self.retryButton = button
                    self.bottomStackView.addArrangedSubview(button)
                }
            }
        }
    }
    
}
