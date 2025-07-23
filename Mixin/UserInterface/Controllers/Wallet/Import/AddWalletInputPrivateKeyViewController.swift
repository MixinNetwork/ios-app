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
        let address: String
        let chainID: String
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
        inputTextView.delegate = self
        inputPlaceholderLabel.text = R.string.localizable.type_your_private_key()
        descriptionLabel.text = R.string.localizable.private_key_storage_description()
        continueButton.configuration?.title = R.string.localizable.import()
    }
    
    override func continueToNext(_ sender: Any) {
        guard let wallet else {
            return
        }
        let importing = AddWalletImportingViewController(
            importingWallet: .byPrivateKey(
                key: wallet.privateKey,
                address: wallet.address,
                chainID: wallet.chainID
            )
        )
        navigationController?.pushViewController(importing, animated: true)
    }
    
    override func detectInput() {
        errorDescriptionLabel.text = nil
        let input = (inputTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            inputPlaceholderLabel.isHidden = false
            wallet = nil
            return
        }
        inputPlaceholderLabel.isHidden = true
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
                    address: account.address.toChecksumAddress(),
                    chainID: ChainID.ethereum
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
                    address: publicKey,
                    chainID: ChainID.solana
                )
            }
        } catch {
            Logger.general.debug(category: "InputPrivateKey", message: "\(error)")
            wallet = nil
        }
    }
    
}

extension AddWalletInputPrivateKeyViewController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        detectInput()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            if wallet == nil {
                errorDescriptionLabel.text = R.string.localizable.invalid_format()
            } else {
                errorDescriptionLabel.text = nil
            }
            return false
        } else {
            return true
        }
    }
    
}
