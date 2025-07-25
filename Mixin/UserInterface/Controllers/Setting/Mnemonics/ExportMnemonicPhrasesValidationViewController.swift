import UIKit
import MixinServices

final class ExportMnemonicPhrasesValidationViewController: ErrorReportingPINValidationViewController {
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        let userID = myUserId
        Task { [weak self] in
            do {
                guard let userIDData = userID.data(using: .utf8) else {
                    throw TIP.Error.invalidUserID
                }
                let salt = try await TIP.salt(pin: pin)
                let mnemonics = try MixinMnemonics(entropy: salt)
                let masterKey = try MasterKey.key(from: mnemonics)
                let publicKey = masterKey.publicKey.rawRepresentation.hexEncodedString()
                let signature = try masterKey.signature(for: userIDData).hexEncodedString()
                AccountAPI.exportSalt(
                    pin: pin,
                    userID: userID,
                    masterPublicKey: publicKey,
                    masterSignature: signature
                ) { result in
                    switch result {
                    case .success(let account):
                        LoginManager.shared.setAccount(account)
                        if let self {
                            let reveal = ViewMnemonicsViewController(mnemonics: mnemonics)
                            self.navigationController?.pushViewController(replacingCurrent: reveal, animated: true)
                        }
                    case .failure(let error):
                        self?.handle(error: error)
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
