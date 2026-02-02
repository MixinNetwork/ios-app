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
        switch action {
        case .addWallet(.create):
            titleLabel.text = R.string.localizable.enter_pin_create_wallet()
            continueButton.setTitle(R.string.localizable.create_new_wallet(), for: .normal)
        default:
            titleLabel.text = R.string.localizable.enter_your_pin_to_continue()
            continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        }
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
                        let pathIndex = try SequentialWalletPathGenerator.nextPathIndex(walletCategory: .classic)
                        let addresses = try await TIP.deriveAddresses(pin: pin, index: pathIndex)
                        let request = CreateSigningWalletRequest(
                            name: R.string.localizable.common_wallet_index("\(nameIndex)"),
                            category: .classic,
                            addresses: addresses
                        )
                        await MainActor.run {
                            let importing = AddWalletImportingViewController(
                                importingWallet: .byCreating(request: request)
                            )
                            navigationController?.pushViewController(replacingCurrent: importing, animated: true)
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
                        try await AccountAPI.verify(pin: pin)
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
