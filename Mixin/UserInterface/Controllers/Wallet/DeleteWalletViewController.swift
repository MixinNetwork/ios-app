import UIKit
import MixinServices

final class DeleteWalletViewController: UIViewController {
    
    private let walletID: String
    private let onDeleted: () -> Void
    
    init(walletID: String, onDeleted: @escaping () -> Void) {
        self.walletID = walletID
        self.onDeleted = onDeleted
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let label = UILabel()
        label.textColor = R.color.text_secondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        label.adjustsFontForContentSizeCategory = true
        label.text = R.string.localizable.delete_wallet_description()
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(36)
            make.trailing.equalToSuperview().offset(-36)
            make.top.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-50)
        }
    }
    
}

extension DeleteWalletViewController: AuthenticationIntent {
    
    var intentTitle: String {
        R.string.localizable.delete_wallet_title()
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
        [.neverRequestAddBiometricAuthentication, .becomesFirstResponderOnAppear, .viewUnderPINField, .destructiveTitle]
    }
    
    func authenticationViewController(
        _ controller: AuthenticationViewController,
        didInput pin: String,
        completion: @escaping @MainActor (AuthenticationViewController.AuthenticationResult) -> Void
    ) {
        AccountAPI.verify(pin: pin) { [walletID, onDeleted] result in
            switch result {
            case .success:
                RouteAPI.deleteWallet(id: walletID) { result in
                    switch result {
                    case .success:
                        let addresses = Web3WalletDAO.shared.deleteWallet(id: walletID)
                        AppGroupKeychain.deleteEncryptedWalletPrivateKey(addresses: addresses)
                        completion(.success)
                        controller.presentingViewController?.dismiss(animated: true) {
                            onDeleted()
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
