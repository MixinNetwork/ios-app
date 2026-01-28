import UIKit
import web3
import MixinServices
import TIP

final class ReimportPrivateKeyViewController: InputOnChainInfoViewController {
    
    private enum LoadKeyError: Error {
        case invalidInput
        case invalidLength
        case mismatchedKeyPair
        case mismatchedAddress
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
                let privateKey: Data
                do {
                    privateKey = try Bitcoin.privateKey(wif: input)
                } catch {
                    let key = if input.hasPrefix("0x") {
                        Data(hexEncodedString: input.dropFirst(2))
                    } else {
                        Data(hexEncodedString: input)
                    }
                    if let key, key.count == Bitcoin.privateKeyLength {
                        privateKey = key
                    } else {
                        throw LoadKeyError.invalidInput
                    }
                }
                let address = try Bitcoin.segwitAddress(privateKey: privateKey)
                let validationAddress = try {
                    let key = if input.hasPrefix("0x") {
                        String(input.dropFirst(2))
                    } else {
                        input
                    }
                    var error: NSError?
                    let address = BlockchainGenerateBitcoinSegwitAddressFromPrivateKey(key, &error)
                    if let error {
                        throw error
                    }
                    return address
                }()
                guard address == validationAddress else {
                    throw LoadKeyError.mismatchedAddress
                }
                guard addresses.allSatisfy({ $0.destination == address }) else {
                    throw LoadKeyError.mismatchedWallet
                }
                encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
            case .evm:
                let privateKey = if input.hasPrefix("0x") {
                    Data(hexEncodedString: input.dropFirst(2))
                } else {
                    Data(hexEncodedString: input)
                }
                guard let privateKey else {
                    throw LoadKeyError.invalidInput
                }
                let keyStorage = InPlaceKeyStorage(raw: privateKey)
                let account = try EthereumAccount(keyStorage: keyStorage)
                let address = account.address.toChecksumAddress()
                let validationAddress = try {
                    let key = if input.hasPrefix("0x") {
                        String(input.dropFirst(2))
                    } else {
                        input
                    }
                    var error: NSError?
                    let address = BlockchainGenerateEvmAddressFromPrivateKey(key, &error)
                    if let error {
                        throw error
                    }
                    return address
                }()
                guard address == validationAddress else {
                    throw LoadKeyError.mismatchedAddress
                }
                guard addresses.allSatisfy({ $0.destination == address }) else {
                    throw LoadKeyError.mismatchedWallet
                }
                encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
            case .solana:
                let inputData: Data
                if let base58Decoded = Data(base58EncodedString: input) {
                    inputData = base58Decoded
                } else {
                    let hexDecoded = if input.hasPrefix("0x") {
                        Data(hexEncodedString: input.dropFirst(2))
                    } else {
                        Data(hexEncodedString: input)
                    }
                    if let hexDecoded {
                        inputData = hexDecoded
                    } else {
                        throw LoadKeyError.invalidInput
                    }
                }
                
                let privateKey: Data
                let publicKey: String
                switch inputData.count {
                case Solana.privateKeyCount:
                    privateKey = inputData
                    publicKey = try Solana.publicKey(seed: privateKey)
                case Solana.keyPairCount:
                    let publicKeyIndex = inputData.index(inputData.startIndex, offsetBy: 32)
                    privateKey = inputData[inputData.startIndex..<publicKeyIndex]
                    publicKey = inputData[publicKeyIndex...].base58EncodedString()
                    let derivedPublicKey = try Solana.publicKey(seed: privateKey)
                    guard publicKey == derivedPublicKey else {
                        throw LoadKeyError.mismatchedKeyPair
                    }
                default:
                    throw LoadKeyError.invalidLength
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
            Logger.web3.error(category: "ReimportPrivateKey", message: "\(error)")
            encryptedPrivateKey = nil
            errorDescriptionLabel.text = R.string.localizable.invalid_format()
        }
    }
    
}
