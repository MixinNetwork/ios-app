import UIKit
import MixinServices

final class ReimportMnemonicsViewController: InputBIP39MnemonicsViewController {
    
    private enum ReimportError: Error {
        case missingPath
        case invalidChain(String)
        case mismatched
    }
    
    private let wallet: Web3Wallet
    
    private var addresses: [Web3Address]?
    private var encryptedMnemonics: EncryptedBIP39Mnemonics?
    
    init(wallet: Web3Wallet, encryptionKey: Data) {
        self.wallet = wallet
        super.init(encryptionKey: encryptionKey)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global().async { [weak self, walletID=wallet.walletID] in
            let addresses = Web3AddressDAO.shared.addresses(walletID: walletID)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.addresses = addresses
                self.detectPhrases(self)
            }
        }
    }
    
    override func confirm(_ sender: Any) {
        guard let encryptedMnemonics else {
            return
        }
        AppGroupKeychain.setImportedMnemonics(encryptedMnemonics, forWalletID: wallet.walletID)
        showAutoHiddenHud(style: .notification, text: R.string.localizable.wallet_candidate_imported())
        navigationController?.popViewController(animated: true)
    }
    
    override func detectPhrases(_ sender: Any) {
        let phrases = self.textFieldPhrases
        guard let addresses, !phrases.contains(where: \.isEmpty) else {
            encryptedMnemonics = nil
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = false
            return
        }
        do {
            let mnemonics = try BIP39Mnemonics(phrases: phrases)
            for address in addresses {
                guard let pathString = address.path else {
                    throw ReimportError.missingPath
                }
                guard let kind = Web3Chain.chain(chainID: address.chainID)?.kind else {
                    throw ReimportError.invalidChain(address.chainID)
                }
                let path = try DerivationPath(string: pathString)
                let derivedAddress = switch kind {
                case .evm:
                    try mnemonics.deriveForEVM(path: path).address
                case .solana:
                    try mnemonics.deriveForSolana(path: path).address
                }
                if derivedAddress != address.destination {
                    throw ReimportError.mismatched
                }
            }
            encryptedMnemonics = try EncryptedBIP39Mnemonics(
                mnemonics: mnemonics,
                key: encryptionKey
            )
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = true
        } catch {
            Logger.general.error(category: "ReimportMnemonics", message: "\(error)")
            encryptedMnemonics = nil
            errorDescriptionLabel.text = switch error {
            case ReimportError.mismatched:
                R.string.localizable.invalid_secret_for_wallet(R.string.localizable.mnemonic_phrase())
            default:
                R.string.localizable.invalid_mnemonic_phrase()
            }
            errorDescriptionLabel.isHidden = false
            confirmButton.isEnabled = false
        }
    }
    
}
