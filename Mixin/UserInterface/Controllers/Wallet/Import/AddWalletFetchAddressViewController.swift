import UIKit
import CryptoKit
import MixinServices

final class AddWalletFetchAddressViewController: IntroductionViewController {
    
    private let mnemonics: BIP39Mnemonics
    private let encryptedMnemonics: EncryptedBIP39Mnemonics
    private let busyIndicator = ActivityIndicatorView()
    private let searchWalletDerivationsCount: UInt32 = 10
    
    init(mnemonics: BIP39Mnemonics, encryptedMnemonics: EncryptedBIP39Mnemonics) {
        self.mnemonics = mnemonics
        self.encryptedMnemonics = encryptedMnemonics
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
        titleLabel.text = R.string.localizable.fetching_in_to_your_wallet()
        
        contentLabelTopConstraint.constant = 16
        contentLabel.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
        contentLabel.adjustsFontForContentSizeCategory = true
        contentLabel.textAlignment = .center
        
        busyIndicator.tintColor = R.color.outline_primary()
        actionStackView.addArrangedSubview(busyIndicator)
        busyIndicator.snp.makeConstraints { make in
            make.height.equalTo(48)
        }
        
        fetchAddresses(mnemonics: mnemonics)
    }
    
    @objc private func retry(_ sender: Any) {
        fetchAddresses(mnemonics: mnemonics)
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
    
    private func fetchAddresses(mnemonics: BIP39Mnemonics) {
        showLoading()
        let lastPathIndex: UInt32 = searchWalletDerivationsCount - 1
        DispatchQueue.global().async { [weak self, encryptedMnemonics] in
            let wallets: [BIP39Mnemonics.DerivedWallet]
            do {
                wallets = try mnemonics.deriveWallets(indices: 0...lastPathIndex)
            } catch {
                DispatchQueue.main.async {
                    self?.showError(error.localizedDescription)
                }
                return
            }
            let addresses = wallets.flatMap { wallet in
                [wallet.evm.address, wallet.solana.address]
            }
            let firstNameIndex = SequentialWalletNameGenerator.nextNameIndex(category: .common)
            let walletNames = Web3WalletDAO.shared.walletNames()
            RouteAPI.assets(searchAddresses: addresses, queue: .global()) { result in
                switch result {
                case let .success(assets):
                    let candidates: [WalletCandidate]
                    if assets.isEmpty {
                        let wallet = wallets[0]
                        let name = walletNames[wallet.evm.address] ?? walletNames[wallet.solana.address]
                        candidates = [
                            .empty(
                                evmWallet: wallet.evm,
                                solanaWallet: wallet.solana,
                                importedAsName: name
                            )
                        ]
                    } else {
                        let tokens = assets.reduce(into: [:]) { result, addressAssets in
                            result[addressAssets.address] = addressAssets.assets
                        }
                        candidates = wallets.compactMap { wallet in
                            let evmTokens = tokens[wallet.evm.address] ?? []
                            let solanaTokens = tokens[wallet.solana.address] ?? []
                            let tokens = evmTokens + solanaTokens
                            let name = walletNames[wallet.evm.address] ?? walletNames[wallet.solana.address]
                            return tokens.isEmpty ? nil : WalletCandidate(
                                evmWallet: wallet.evm,
                                solanaWallet: wallet.solana,
                                tokens: tokens,
                                importedAsName: name
                            )
                        }
                    }
                    DispatchQueue.main.async {
                        let selector = AddWalletSelectorViewController(
                            mnemonics: mnemonics,
                            encryptedMnemonics: encryptedMnemonics,
                            candidates: candidates,
                            lastPathIndex: lastPathIndex,
                            firstNameIndex: firstNameIndex
                        )
                        self?.navigationController?.pushViewController(replacingCurrent: selector, animated: true)
                    }
                case let .failure(error):
                    Logger.general.debug(category: "AddWallet", message: "\(error)")
                    DispatchQueue.main.async {
                        self?.showError(error.localizedDescription)
                    }
                }
            }
        }
    }
    
}
