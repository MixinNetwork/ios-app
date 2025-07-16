import UIKit
import MixinServices

final class ExportImportedSecretValidationViewController: ErrorReportingPINValidationViewController {
    
    private let secret: ImportedSecret
    
    init(secret: ImportedSecret) {
        self.secret = secret
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        Task { [weak self, secret] in
            do {
                switch secret {
                case .mnemonics(let encryptedMnemonics):
                    let key = try await TIP.importedMnemonicsEncryptionKey(pin: pin)
                    let mnemonics = try encryptedMnemonics.decrypt(with: key)
                    await MainActor.run {
                        let view = ExportImportedMnemonicsViewController(mnemonics: mnemonics)
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
