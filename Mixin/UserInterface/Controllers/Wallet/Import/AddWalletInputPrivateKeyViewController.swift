import UIKit
import web3
import MixinServices

final class AddWalletInputPrivateKeyViewController: AddWalletInputOnChainInfoViewController {
    
    private enum LoadKeyError: Error {
        case invalidHex
        case invalidBase58
        case invalidLength
        case mismatchedPublicKey
        case alreadyImported
    }
    
    private struct Wallet {
        let privateKey: EncryptedPrivateKey
        let address: CreateSigningWalletRequest.SignedAddress
    }
    
    private let encryptionKey: Data
    
    private var wallet: Wallet? {
        didSet {
            continueButton.isEnabled = wallet != nil
        }
    }
    
    init(encryptionKey: Data) {
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
    }
    
    override func continueToNext(_ sender: Any) {
        guard let wallet else {
            return
        }
        let nameIndex = SequentialWalletNameGenerator.nextNameIndex(category: .common)
        let request = CreateSigningWalletRequest(
            name: R.string.localizable.common_wallet_index("\(nameIndex)"),
            category: .importedPrivateKey,
            addresses: [wallet.address]
        )
        let importing = AddWalletImportingViewController(
            importingWallet: .byPrivateKey(key: wallet.privateKey, request: request)
        )
        navigationController?.pushViewController(importing, animated: true)
    }
    
    override func detectInput() {
        super.detectInput()
        guard let userID = LoginManager.shared.account?.userID else {
            return
        }
        let input = (inputTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, let importedAddresses else {
            wallet = nil
            errorDescriptionLabel.text = nil
            return
        }
        do {
            switch selectedChain.kind {
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
                if importedAddresses.contains(address) {
                    throw LoadKeyError.alreadyImported
                }
                let encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
                wallet = try Wallet(
                    privateKey: encryptedPrivateKey,
                    address: .init(
                        destination: address,
                        chainID: ChainID.ethereum,
                        path: nil,
                        userID: userID
                    ) { message in
                        try account.signMessage(message: message)
                    }
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
                if importedAddresses.contains(publicKey) {
                    throw LoadKeyError.alreadyImported
                }
                let derivedPublicKey = try Solana.publicKey(seed: privateKey)
                guard publicKey == derivedPublicKey else {
                    throw LoadKeyError.mismatchedPublicKey
                }
                let encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
                wallet = try Wallet(
                    privateKey: encryptedPrivateKey,
                    address: .init(
                        destination: publicKey,
                        chainID: ChainID.solana,
                        path: nil,
                        userID: userID
                    ) { message in
                        try Solana.sign(
                            message: message,
                            withPrivateKeyFrom: privateKey,
                            format: .hex
                        )
                    }
                )
            }
            errorDescriptionLabel.text = nil
        } catch LoadKeyError.alreadyImported {
            wallet = nil
            errorDescriptionLabel.text = R.string.localizable.wallet_already_added()
        } catch {
            Logger.general.debug(category: "InputPrivateKey", message: "\(error)")
            wallet = nil
            errorDescriptionLabel.text = R.string.localizable.invalid_format()
        }
    }
    
}
