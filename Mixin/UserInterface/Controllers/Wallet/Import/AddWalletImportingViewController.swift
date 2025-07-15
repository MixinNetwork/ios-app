import UIKit
import MixinServices

final class AddWalletImportingViewController: IntroductionViewController {
    
    private let encryptedMnemonics: EncryptedBIP39Mnemonics
    private let wallets: [NamedWalletCandidate]
    private let busyIndicator = ActivityIndicatorView()
    
    init(
        encryptedMnemonics: EncryptedBIP39Mnemonics,
        wallets: [NamedWalletCandidate]
    ) {
        self.encryptedMnemonics = encryptedMnemonics
        self.wallets = wallets
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            40
        case .medium:
            80
        case .long, .extraLong:
            120
        }
        imageView.image = R.image.mnemonic_login()
        titleLabel.text = R.string.localizable.importing_into_your_wallet()
        
        contentLabelTopConstraint.constant = 16
        contentLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        contentLabel.adjustsFontForContentSizeCategory = true
        contentLabel.textAlignment = .center
        
        busyIndicator.tintColor = R.color.outline_primary()
        actionStackView.addArrangedSubview(busyIndicator)
        busyIndicator.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
        
        importWallets(wallets)
    }
    
    @objc private func retry(_ sender: Any) {
        importWallets(wallets)
    }
    
    private func showLoading() {
        busyIndicator.startAnimating()
        actionButton.isHidden = true
        contentLabel.textColor = R.color.text_tertiary()
        contentLabel.text = R.string.localizable.mnemonic_phrase_take_long()
        contentLabel.isHidden = false
    }
    
    private func showError(_ description: String) {
        busyIndicator.stopAnimating()
        actionButton.style = .filled
        actionButton.setTitle(R.string.localizable.retry(), for: .normal)
        actionButton.addTarget(self, action: #selector(retry(_:)), for: .touchUpInside)
        actionButton.isHidden = false
        contentLabel.textColor = R.color.error_red()
        contentLabel.text = description
        contentLabel.isHidden = false
    }
    
    private func importWallets(_ wallets: [NamedWalletCandidate]) {
        showLoading()
        Task { [weak self, encryptedMnemonics] in
            do {
                for wallet in wallets {
                    let evmWallet = wallet.candidate.evmWallet
                    let solanaWallet = wallet.candidate.solanaWallet
                    let request = RouteAPI.WalletRequest(
                        name: wallet.name,
                        category: .importedMnemonic,
                        addresses: [
                            .init(
                                destination: evmWallet.address,
                                chainID: ChainID.ethereum,
                                path: evmWallet.path.string
                            ),
                            .init(
                                destination: solanaWallet.address,
                                chainID: ChainID.solana,
                                path: solanaWallet.path.string
                            ),
                        ]
                    )
                    let response = try await RouteAPI.createWallet(request)
                    Web3WalletDAO.shared.save(wallets: [response.wallet], addresses: response.addresses)
                    let jobs = [
                        RefreshWeb3WalletTokenJob(walletID: response.wallet.walletID),
                        SyncWeb3TransactionJob(walletID: response.wallet.walletID),
                    ]
                    for job in jobs {
                        ConcurrentJobQueue.shared.addJob(job: job)
                    }
                    AppGroupKeychain.setImportedMnemonics(encryptedMnemonics, forWalletID: response.wallet.walletID)
                }
                await MainActor.run {
                    _ = self?.navigationController?.popToRootViewController(animated: true)
                }
            } catch {
                await MainActor.run {
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }
    
}
