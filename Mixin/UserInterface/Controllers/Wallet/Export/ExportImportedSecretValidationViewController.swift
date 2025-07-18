import UIKit
import MixinServices
import TIP

final class ExportImportedSecretValidationViewController: ErrorReportingPINValidationViewController {
    
    private enum ExportError: Error {
        case mismatch
    }
    
    private let secret: ImportedSecret
    
    init(secret: ImportedSecret) {
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
                switch secret {
                case let .mnemonics(encryptedMnemonics):
                    let key = try await TIP.importedMnemonicsEncryptionKey(pin: pin)
                    let mnemonics = try encryptedMnemonics.decrypt(with: key)
                    await MainActor.run {
                        let view = ExportImportedMnemonicsViewController(mnemonics: mnemonics)
                        self?.navigationController?.pushViewController(replacingCurrent: view, animated: true)
                    }
                case let .privateKeyFromMnemonics(encryptedMnemonics, kind, path):
                    let key = try await TIP.importedMnemonicsEncryptionKey(pin: pin)
                    let mnemonics = try encryptedMnemonics.decrypt(with: key)
                    var error: NSError?
                    let privateKey: String
                    switch kind {
                    case .evm:
                        let data = try mnemonics.deriveForEVM(path: path).privateKey
                        privateKey = "0x" + data.hexEncodedString()
                        let redundantPrivateKey = BlockchainExportEvmPrivateKey(mnemonics.joinedPhrases, path.string, &error)
                        if let error {
                            throw error
                        } else if privateKey != redundantPrivateKey {
                            throw ExportError.mismatch
                        }
                    case .solana:
                        let derivation = try mnemonics.deriveForSolana(path: path)
                        privateKey = try Solana.expandedPrivateKey(derivation: derivation)
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
                }
            } catch {
                await MainActor.run {
                    self?.handle(error: error)
                }
            }
        }
    }
    
}
