import UIKit
import MixinServices

final class ExportMnemonicPhrasesValidationViewController: FullscreenPINValidationViewController {
    
    override var isBusy: Bool {
        didSet {
            if isBusy {
                errorDescriptionLabel?.isHidden = true
            }
        }
    }
    
    private weak var errorDescriptionLabel: UILabel?
    
    static func contained() -> ContainerViewController {
        let viewController = ExportMnemonicPhrasesValidationViewController()
        let container = ContainerViewController.instance(viewController: viewController, title: "")
        return container
    }
    
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
                let mnemonics = try Mnemonics(entropy: salt)
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
                            let reveal = ViewMnemonicsViewController.contained(mnemonics: mnemonics)
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
    
    private func handle(error: Error) {
        isBusy = false
        pinField.clear()
        let label: UILabel
        if let l = errorDescriptionLabel {
            label = l
            label.isHidden = false
        } else {
            label = UILabel()
            label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
            label.adjustsFontForContentSizeCategory = true
            label.textColor = R.color.error_red()
            label.textAlignment = .center
            label.numberOfLines = 0
            contentStackView.addArrangedSubview(label)
            errorDescriptionLabel = label
        }
        label.text = error.localizedDescription
    }
    
}
