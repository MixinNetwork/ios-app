import UIKit
import MixinServices

final class ExportMnemonicPhrasesValidationViewController: ErrorReportingPINValidationViewController {
    
    override func continueAction(_ sender: Any) {
        isBusy = true
        let pin = pinField.text
        let userID = myUserId
        Task { [weak self] in
            do {
                let request = try await ExportSaltRequest(userID: userID, pin: pin)
                let account = try await AccountAPI.exportSalt(request: request)
                LoginManager.shared.setAccount(account)
                await MainActor.run {
                    let reveal = ViewMnemonicsViewController(mnemonics: request.mnemonics)
                    self?.navigationController?.pushViewController(replacingCurrent: reveal, animated: true)
                }
            } catch {
                await MainActor.run {
                    self?.handle(error: error)
                }
            }
        }
    }
    
}
