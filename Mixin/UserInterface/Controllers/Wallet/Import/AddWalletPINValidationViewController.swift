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
                switch action {
                case let .addWallet(method):
                    switch method {
                    case .create:
                        let nameIndex = SequentialWalletNameGenerator.nextNameIndex(category: .common)
                        let pathIndex = Web3WalletDAO.shared.walletCount(category: .classic) + 1
                        let addresses = try await TIP.deriveAddresses(pin: pin, index: pathIndex)
                        let request = CreateWalletRequest(
                            name: R.string.localizable.common_wallet_index("\(nameIndex)"),
                            category: .classic,
                            addresses: addresses
                        )
                        await MainActor.run {
                            let introduction = CreateWalletIntroductionViewController(request: request)
                            self.navigationController?.pushViewController(replacingCurrent: introduction, animated: true)
                        }
                    case .privateKey:
                        let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                        await MainActor.run {
                            let input = AddWalletInputPrivateKeyViewController(encryptionKey: key)
                            self.navigationController?.pushViewController(replacingCurrent: input, animated: true)
                        }
                    case .mnemonics:
                        let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                        await MainActor.run {
                            let input = AddWalletInputMnemonicsViewController(encryptionKey: key)
                            self.navigationController?.pushViewController(replacingCurrent: input, animated: true)
                        }
                    case .watch:
                        await MainActor.run {
                            let input = AddWalletInputAddressViewController()
                            self.navigationController?.pushViewController(replacingCurrent: input, animated: true)
                        }
                    }
                case let .reimportMnemonics(wallet):
                    let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                    await MainActor.run {
                        let input = ReimportMnemonicsViewController(wallet: wallet, encryptionKey: key)
                        self.navigationController?.pushViewController(replacingCurrent: input, animated: true)
                    }
                case let .reimportPrivateKey(wallet):
                    let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                    await MainActor.run {
                        let input = ReimportPrivateKeyViewController(wallet: wallet, encryptionKey: key)
                        self.navigationController?.pushViewController(replacingCurrent: input, animated: true)
                    }
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
