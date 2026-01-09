import UIKit
import web3
import MixinServices

final class ReimportPrivateKeyViewController: InputOnChainInfoViewController {
    
    private enum LoadKeyError: Error {
        case invalidHex
        case invalidBase58
        case invalidLength
        case mismatchedPublicKey
        case mismatchedWallet
    }
    
    private let wallet: Web3Wallet
    private let encryptionKey: Data
    
    private var addresses: [Web3Address]?
    
    private var encryptedPrivateKey: EncryptedPrivateKey? {
        didSet {
            continueButton.isEnabled = encryptedPrivateKey != nil
        }
    }
    
    init(wallet: Web3Wallet, encryptionKey: Data) {
        self.wallet = wallet
        self.encryptionKey = encryptionKey
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.import_private_key()
        inputPlaceholderLabel.text = R.string.localizable.type_your_private_key()
        let descriptionLabel = InsetLabel()
        descriptionLabel.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        descriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        descriptionLabel.textColor = R.color.text_tertiary()
        descriptionLabel.numberOfLines = 0
        descriptionLabel.text = R.string.localizable.private_key_storage_description()
        contentStackView.addArrangedSubview(descriptionLabel)
        continueButton.configuration?.title = R.string.localizable.import()
        DispatchQueue.global().async { [weak self, walletID=wallet.walletID] in
            let addresses = Web3AddressDAO.shared.addresses(walletID: walletID)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.addresses = addresses
                self.detectInput()
            }
        }
    }
    
    override func continueToNext(_ sender: Any) {
        guard let encryptedPrivateKey else {
            return
        }
        AppGroupKeychain.setImportedPrivateKey(encryptedPrivateKey, forWalletID: wallet.walletID)
        navigationController?.popViewController(animated: true)
    }
    
    override func detectInput() {
        super.detectInput()
        let input = (inputTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, let addresses else {
            encryptedPrivateKey = nil
            errorDescriptionLabel.text = nil
            return
        }
        do {
            switch selectedChain.kind {
            case .bitcoin:
                let privateKey = try Bitcoin.privateKey(wif: input)
                let address = try Bitcoin.segwitAddress(privateKey: privateKey)
                guard addresses.allSatisfy({ $0.destination == address }) else {
                    throw LoadKeyError.mismatchedWallet
                }
                encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
            case .evm:
                let hex = if input.hasPrefix("0x") {
                    String(input.dropFirst(2))
                } else {
                    input
                }
                guard let privateKey = Data(hexEncodedString: hex) else {
                    throw LoadKeyError.invalidHex
                }
                let keyStorage = InPlaceKeyStorage(raw: privateKey)
                let account = try EthereumAccount(keyStorage: keyStorage)
                let address = account.address.toChecksumAddress()
                guard addresses.allSatisfy({ $0.destination == address }) else {
                    throw LoadKeyError.mismatchedWallet
                }
                encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
            case .solana:
                guard let keyPair = Data(base58EncodedString: input) else {
                    throw LoadKeyError.invalidBase58
                }
                guard keyPair.count == Solana.keyPairCount else {
                    throw LoadKeyError.invalidLength
                }
                let publicKeyIndex = keyPair.index(keyPair.startIndex, offsetBy: 32)
                let privateKey = keyPair[keyPair.startIndex..<publicKeyIndex]
                let publicKey = keyPair[publicKeyIndex...].base58EncodedString()
                let derivedPublicKey = try Solana.publicKey(seed: privateKey)
                guard publicKey == derivedPublicKey else {
                    throw LoadKeyError.mismatchedPublicKey
                }
                guard addresses.allSatisfy({ $0.destination == publicKey }) else {
                    throw LoadKeyError.mismatchedWallet
                }
                encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
            }
            errorDescriptionLabel.text = nil
        } catch LoadKeyError.mismatchedWallet {
            encryptedPrivateKey = nil
            errorDescriptionLabel.text = R.string.localizable.invalid_secret_for_wallet(R.string.localizable.private_key())
        } catch {
            Logger.general.debug(category: "ReimportPrivateKey", message: "\(error)")
            encryptedPrivateKey = nil
            errorDescriptionLabel.text = R.string.localizable.invalid_format()
        }
    }
    
}
