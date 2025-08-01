import UIKit
import MixinServices

final class AddWalletPINValidationViewController: ErrorReportingPINValidationViewController {
    
    enum Action {
        case addWallet(AddWalletMethod)
        case reimportMnemonics(Web3Wallet)
        case reimportPrivateKey(Web3Wallet)
    }
    
    private let action: Action
    
    init(action: Action) {
        self.action = action
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.enter_your_pin_to_continue()
    }
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        Task {
            do {
                let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                await MainActor.run {
                    let input = switch action {
                    case let .addWallet(method):
                        switch method {
                        case .privateKey:
                            AddWalletInputPrivateKeyViewController(encryptionKey: key)
                        case .mnemonics:
                            AddWalletInputMnemonicsViewController(encryptionKey: key)
                        case .watch:
                            AddWalletInputAddressViewController()
                        }
                    case let .reimportMnemonics(wallet):
                        ReimportMnemonicsViewController(wallet: wallet, encryptionKey: key)
                    case let .reimportPrivateKey(wallet):
                        ReimportPrivateKeyViewController(wallet: wallet, encryptionKey: key)
                    }
                    self.navigationController?.pushViewController(replacingCurrent: input, animated: true)
                }
            } catch {
                await MainActor.run {
                    self.pinField.clear()
                    self.isBusy = false
                    if let error = error as? MixinAPIError {
                        PINVerificationFailureHandler.handle(error: error) { (description) in
                            self.alert(description)
                        }
                    } else {
                        self.handle(error: error)
                    }
                }
            }
        }
    }
    
}
