import UIKit
import MixinServices

final class ReimportMnemonicsViewController: InputBIP39MnemonicsViewController {
    
    private enum ReimportError: Error {
        case missingPath
        case invalidChain(String)
        case mismatched
    }
    
    private struct Importable {
        let encryptedMnemonics: EncryptedBIP39Mnemonics
        let addresses: [CreateSigningWalletRequest.SignedAddress]?
    }
    
    private let wallet: Web3Wallet
    
    private var addresses: [Web3Address]?
    private var importable: Importable?
    
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
        guard let importable else {
            return
        }
        if let addresses = importable.addresses {
            confirmButton.isBusy = true
            Task {
                do {
                    let addresses = try await RouteAPI.updateWallet(
                        id: wallet.walletID,
                        appendingAddresses: addresses
                    )
                    Web3AddressDAO.shared.save(addresses: addresses)
                    await MainActor.run {
                        self.save(mnemonics: importable.encryptedMnemonics)
                    }
                } catch {
                    await MainActor.run {
                        self.errorDescriptionLabel.text = error.localizedDescription
                        self.errorDescriptionLabel.isHidden = false
                        self.confirmButton.isBusy = false
                    }
                }
            }
        } else {
            save(mnemonics: importable.encryptedMnemonics)
        }
    }
    
    override func detectPhrases(_ sender: Any) {
        let phrases = self.textFieldPhrases
        guard let addresses, !phrases.contains(where: \.isEmpty) else {
            importable = nil
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
                case .bitcoin:
                    try mnemonics.deriveForBitcoin(path: path).address
                case .evm:
                    try mnemonics.deriveForEVM(path: path).address
                case .solana:
                    try mnemonics.deriveForSolana(path: path).address
                }
                if derivedAddress != address.destination {
                    throw ReimportError.mismatched
                }
            }
            let hasBitcoinAddress = addresses.contains { address in
                address.chainID == ChainID.bitcoin
            }
            let pendingUpdateAddresses: [CreateSigningWalletRequest.SignedAddress]?
            if hasBitcoinAddress {
                pendingUpdateAddresses = nil
            } else {
                let index = try SequentialWalletPathGenerator.maxIndex(
                    paths: addresses.compactMap(\.path)
                )
                let path = try DerivationPath.bitcoin(index: index)
                let derivation = try mnemonics.deriveForBitcoin(path: path)
                let bitcoinAddress = try CreateSigningWalletRequest.SignedAddress(
                    destination: derivation.address,
                    chainID: ChainID.bitcoin,
                    path: path.string,
                    userID: myUserId
                ) { message in
                    try Bitcoin.sign(message: message, with: derivation.privateKey)
                }
                pendingUpdateAddresses = [bitcoinAddress]
            }
            let encryptedMnemonics = try EncryptedBIP39Mnemonics(
                mnemonics: mnemonics,
                key: encryptionKey
            )
            importable = Importable(
                encryptedMnemonics: encryptedMnemonics,
                addresses: pendingUpdateAddresses
            )
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = true
        } catch {
            Logger.general.error(category: "ReimportMnemonics", message: "\(error)")
            importable = nil
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
    
    private func save(mnemonics: EncryptedBIP39Mnemonics) {
        AppGroupKeychain.setImportedMnemonics(mnemonics, forWalletID: wallet.walletID)
        showAutoHiddenHud(style: .notification, text: R.string.localizable.wallet_candidate_imported())
        navigationController?.popViewController(animated: true)
    }
    
}
