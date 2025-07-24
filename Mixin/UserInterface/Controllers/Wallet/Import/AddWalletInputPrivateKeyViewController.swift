import UIKit
import web3
import MixinServices

final class AddWalletInputPrivateKeyViewController: AddWalletInputOnChainInfoViewController {
    
    private enum LoadKeyError: Error {
        case invalidHex
        case invalidBase58
        case invalidLength
        case mismatchedPublicKey
    }
    
    private struct Wallet {
        let privateKey: EncryptedPrivateKey
        let address: CreateWalletRequest.Address
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
        let importing = AddWalletImportingViewController(
            importingWallet: .byPrivateKey(key: wallet.privateKey, address: wallet.address)
        )
        navigationController?.pushViewController(importing, animated: true)
    }
    
    override func detectInput() {
        super.detectInput()
        let input = (inputTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
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
                let encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
                wallet = Wallet(
                    privateKey: encryptedPrivateKey,
                    address: .init(
                        destination: account.address.toChecksumAddress(),
                        chainID: ChainID.ethereum,
                        path: nil
                    )
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
                let encryptedPrivateKey = try EncryptedPrivateKey(
                    privateKey: privateKey,
                    key: encryptionKey
                )
                wallet = Wallet(
                    privateKey: encryptedPrivateKey,
                    address: .init(
                        destination: publicKey,
                        chainID: ChainID.solana,
                        path: nil
                    )
                )
            }
        } catch {
            Logger.general.debug(category: "InputPrivateKey", message: "\(error)")
            wallet = nil
        }
        if wallet == nil {
            errorDescriptionLabel.text = R.string.localizable.invalid_format()
        } else {
            errorDescriptionLabel.text = nil
        }
    }
    
}
