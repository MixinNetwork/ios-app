import UIKit
import web3
import MixinServices

final class AddWalletInputPrivateKeyViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var networkSelectorBackgroundView: UIView!
    @IBOutlet weak var networkTitleLabel: UILabel!
    @IBOutlet weak var networkNameLabel: UILabel!
    @IBOutlet weak var selectNetworkButton: MenuTriggerButton!
    @IBOutlet weak var privateKeyBackgroundView: UIView!
    @IBOutlet weak var privateKeyTextView: UITextView!
    @IBOutlet weak var privateKeyPlaceholderLabel: InsetLabel!
    @IBOutlet weak var descriptionLabel: InsetLabel!
    @IBOutlet weak var errorDescriptionLabel: UILabel!
    @IBOutlet weak var importButton: UIButton!
    
    private let encryptionKey: Data
    
    private weak var contentHeightConstraint: NSLayoutConstraint!
    
    private var selectedChain: Web3Chain = .solana {
        didSet {
            reloadViews(chain: selectedChain)
            detectInput()
        }
    }
    
    private var wallet: Wallet? {
        didSet {
            importButton.isEnabled = wallet != nil
        }
    }
    
    init(encryptionKey: Data) {
        self.encryptionKey = encryptionKey
        let nib = R.nib.addWalletInputPrivateKeyView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.import_private_key()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        let contentLayoutGuide = UILayoutGuide()
        view.addLayoutGuide(contentLayoutGuide)
        contentLayoutGuide.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
        }
        contentHeightConstraint = contentView.heightAnchor.constraint(equalTo: contentLayoutGuide.heightAnchor, multiplier: 1)
        contentHeightConstraint.isActive = true
        
        for view: UIView in [networkSelectorBackgroundView, privateKeyBackgroundView] {
            view.layer.cornerRadius = 8
            view.layer.masksToBounds = true
        }
        networkTitleLabel.text = R.string.localizable.network()
        selectNetworkButton.showsMenuAsPrimaryAction = true
        reloadViews(chain: selectedChain)
        privateKeyTextView.delegate = self
        privateKeyTextView.textContainerInset = .zero
        privateKeyTextView.textContainer.lineFragmentPadding = 0
        privateKeyTextView.font = UIFontMetrics.default.scaledFont(
            for: .monospacedSystemFont(ofSize: 16, weight: .regular)
        )
        privateKeyPlaceholderLabel.text = R.string.localizable.type_your_private_key()
        descriptionLabel.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        descriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        descriptionLabel.text = R.string.localizable.private_key_storage_description()
        errorDescriptionLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        importButton.configuration?.title = R.string.localizable.import()
        importButton.titleLabel?.adjustsFontForContentSizeCategory = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(layoutContentByKeyboard(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(layoutContentByKeyboard(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @IBAction func pastePrivateKey(_ sender: Any) {
        privateKeyTextView.text = UIPasteboard.general.string
        detectInput()
    }
    
    @IBAction func scanPrivateKey(_ sender: Any) {
        let scanner = CameraViewController.instance()
        scanner.asQrCodeScanner = true
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
    @IBAction func importWallet(_ sender: Any) {
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
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "input_private_key"])
    }
    
    @objc private func layoutContentByKeyboard(_ notification: Notification) {
        switch notification.name {
        case UIResponder.keyboardWillShowNotification:
            contentHeightConstraint.priority = .defaultHigh
        case UIResponder.keyboardWillHideNotification:
            contentHeightConstraint.priority = .defaultLow
        default:
            return
        }
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            options: .overdampedCurve,
            animations: view.layoutIfNeeded
        )
    }
    
}

extension AddWalletInputPrivateKeyViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
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

extension AddWalletInputPrivateKeyViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        privateKeyTextView.text = string
        detectInput()
        return false
    }
    
}

extension AddWalletInputPrivateKeyViewController {
    
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
    
    private func reloadViews(chain: Web3Chain) {
        networkNameLabel.text = chain.name
        selectNetworkButton.menu = UIMenu(children: Web3Chain.all.map { chain in
            UIAction(
                title: chain.name,
                state: chain == selectedChain ? .on : .off,
                handler: { [weak self] _ in self?.selectedChain = chain }
            )
        })
    }
    
    private func detectInput() {
        errorDescriptionLabel.text = nil
        let input = (privateKeyTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            privateKeyPlaceholderLabel.isHidden = false
            wallet = nil
            return
        }
        privateKeyPlaceholderLabel.isHidden = true
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
