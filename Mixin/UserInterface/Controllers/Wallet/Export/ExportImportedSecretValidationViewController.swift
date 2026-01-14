import UIKit
import MixinServices
import TIP

final class ExportImportedSecretValidationViewController: ErrorReportingPINValidationViewController {
    
    private enum ExportError: Error {
        case mismatch
    }
    
    private let secret: ExportingSecret
    
    init(secret: ExportingSecret) {
        self.secret = secret
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.enter_your_pin_to_continue()
    }
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        Task { [weak self, secret] in
            do {
                let key = try await TIP.importedWalletEncryptionKey(pin: pin)
                switch secret {
                case let .mnemonics(encryptedMnemonics):
                    let mnemonics = try encryptedMnemonics.decrypt(with: key)
                    await MainActor.run {
                        let view = ExportImportedMnemonicsViewController(mnemonics: mnemonics)
                        self?.navigationController?.pushViewController(replacingCurrent: view, animated: true)
                    }
                case let .privateKeyFromMnemonics(encryptedMnemonics, kind, path):
                    let mnemonics = try encryptedMnemonics.decrypt(with: key)
                    var error: NSError?
                    let privateKey: String
                    switch kind {
                    case .bitcoin:
                        let derivation = try mnemonics.checkedDerivationForBitcoin(path: path)
                        privateKey = try Bitcoin.wif(privateKey: derivation.privateKey)
                        let redundantPrivateKey = BlockchainExportBitcoinPrivateKey(mnemonics.joinedPhrases, path.string, &error)
                        if let error {
                            throw error
                        } else if privateKey != redundantPrivateKey {
                            throw ExportError.mismatch
                        }
                    case .evm:
                        let data = try mnemonics.checkedDerivationForEVM(path: path).privateKey
                        privateKey = "0x" + data.hexEncodedString()
                        let redundantPrivateKey = BlockchainExportEvmPrivateKey(mnemonics.joinedPhrases, path.string, &error)
                        if let error {
                            throw error
                        } else if privateKey != redundantPrivateKey {
                            throw ExportError.mismatch
                        }
                    case .solana:
                        let derivation = try mnemonics.checkedDerivationForSolana(path: path)
                        privateKey = try Solana.keyPair(derivation: derivation)
                        let redundantPrivateKey = BlockchainExportSolanaPrivateKey(mnemonics.joinedPhrases, path.string, &error)
                        if let error {
                            throw error
                        } else if privateKey != redundantPrivateKey {
                            throw ExportError.mismatch
                        }
                    }
                    await MainActor.run {
                        let view = PrivateKeyViewController(privateKey: privateKey)
                        self?.navigationController?.pushViewController(replacingCurrent: view, animated: true)
                    }
                case let .privateKey(encryptedPrivateKey, kind):
                    let privateKey = try encryptedPrivateKey.decrypt(with: key)
                    let displayPrivateKey = switch kind {
                    case .bitcoin:
                        try Bitcoin.wif(privateKey: privateKey)
                    case .evm:
                        "0x" + privateKey.hexEncodedString()
                    case .solana:
                        try Solana.keyPair(privateKey: privateKey)
                    }
                    await MainActor.run {
                        let view = PrivateKeyViewController(privateKey: displayPrivateKey)
                        self?.navigationController?.pushViewController(replacingCurrent: view, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    self?.handle(error: error)
                }
            }
        }
    }
    
}
