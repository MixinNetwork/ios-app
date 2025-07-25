import UIKit
import MixinServices

final class AddWalletImportingViewController: IntroductionViewController {
    
    enum ImportingWallet {
        case byMnemonics(mnemonics: EncryptedBIP39Mnemonics, wallets: [NamedWalletCandidate])
        case byPrivateKey(key: EncryptedPrivateKey, address: CreateWalletRequest.Address)
    }
    
    private let importingWallet: ImportingWallet
    private let busyIndicator = ActivityIndicatorView()
    
    init(importingWallet: ImportingWallet) {
        self.importingWallet = importingWallet
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
        
        retry(self)
    }
    
    @objc private func retry(_ sender: Any) {
        switch importingWallet {
        case let .byMnemonics(mnemonics, wallets):
            importWallets(mnemonics: mnemonics, wallets: wallets)
        case let .byPrivateKey(key, address):
            importWallets(key: key, address: address)
        }
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
    
    private func importWallets(mnemonics: EncryptedBIP39Mnemonics, wallets: [NamedWalletCandidate]) {
        showLoading()
        Task { [weak self] in
            var hasPartialSuccess = false
            do {
                for wallet in wallets {
                    let evmWallet = wallet.candidate.evmWallet
                    let solanaWallet = wallet.candidate.solanaWallet
                    let request = CreateWalletRequest(
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
                    AppGroupKeychain.setImportedMnemonics(mnemonics, forWalletID: response.wallet.walletID)
                    hasPartialSuccess = true
                }
                await MainActor.run {
                    _ = self?.navigationController?.popToRootViewController(animated: true)
                }
            } catch MixinAPIResponseError.tooManyWallets {
                await MainActor.run {
                    let error = AddWalletErrorViewController(error: .tooManyWallets(hasPartialSuccess: hasPartialSuccess))
                    self?.navigationController?.pushViewController(error, animated: true)
                }
            } catch {
                await MainActor.run {
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func importWallets(key: EncryptedPrivateKey, address: CreateWalletRequest.Address) {
        showLoading()
        Task { [weak self] in
            do {
                let request = CreateWalletRequest(
                    name: R.string.localizable.common_wallet_index(1),
                    category: .importedPrivateKey,
                    addresses: [address]
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
                AppGroupKeychain.setImportedPrivateKey(key, forWalletID: response.wallet.walletID)
                await MainActor.run {
                    _ = self?.navigationController?.popToRootViewController(animated: true)
                }
            } catch MixinAPIResponseError.tooManyWallets {
                await MainActor.run {
                    let error = AddWalletErrorViewController(error: .tooManyWallets(hasPartialSuccess: false))
                    self?.navigationController?.pushViewController(error, animated: true)
                }
            } catch {
                await MainActor.run {
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }
    
}
