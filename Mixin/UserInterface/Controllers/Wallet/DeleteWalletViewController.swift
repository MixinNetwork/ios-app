import UIKit
import MixinServices

final class DeleteWalletViewController: UIViewController {
    
    private let wallet: Web3Wallet
    private let onDeleted: () -> Void
    
    init(wallet: Web3Wallet, onDeleted: @escaping () -> Void) {
        self.wallet = wallet
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
        label.text = switch wallet.category.knownCase {
        case .classic, .importedMnemonic, .importedPrivateKey, .none:
            R.string.localizable.delete_common_wallet_description()
        case .watchAddress:
            R.string.localizable.delete_watch_wallet_description()
        }
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
        AccountAPI.verify(pin: pin) { [wallet, onDeleted] result in
            switch result {
            case .success:
                let walletID = wallet.walletID
                RouteAPI.deleteWallet(id: walletID) { result in
                    switch result {
                    case .success:
                        let jobIDs = [
                            SyncWeb3TransactionJob.jobID(walletID: walletID),
                            ReviewPendingWeb3RawTransactionJob.jobID(walletID: walletID),
                            ReviewPendingWeb3TransactionJob.jobID(walletID: walletID),
                            RefreshWeb3WalletTokenJob.jobID(walletID: walletID),
                            SyncWeb3OrdersJob.jobID(walletID: walletID)
                        ]
                        for id in jobIDs {
                            ConcurrentJobQueue.shared.cancelJob(jobId: id)
                        }
                        Web3WalletDAO.shared.deleteWallet(id: walletID)
                        switch wallet.category.knownCase {
                        case .importedMnemonic:
                            AppGroupKeychain.deleteImportedMnemonics(walletID: walletID)
                        case .importedPrivateKey:
                            AppGroupKeychain.deleteImportedPrivateKey(walletID: walletID)
                        case .classic, .watchAddress, .none:
                            break
                        }
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
