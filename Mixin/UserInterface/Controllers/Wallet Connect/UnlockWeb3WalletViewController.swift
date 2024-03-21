import UIKit
import web3
import MixinServices

final class UnlockWeb3WalletViewController: AuthenticationPreviewViewController {
    
    private let chain: WalletConnectService.Chain
    
    var onDismiss: ((_ isUnlocked: Bool) -> Void)?
    
    private var isUnlocked = false
    
    init(chain: WalletConnectService.Chain) {
        self.chain = chain
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableHeaderView.setIcon { imageView in
            imageView.image = R.image.crypto_wallet()
        }
        layoutTableHeaderView(title: R.string.localizable.unlock_web3_account(chain.name),
                              subtitle: R.string.localizable.unlock_web3_account_description(chain.name))
        let tableFooterView = BulletDescriptionView()
        var lines = [
            R.string.localizable.unlock_web3_account_agreement_1(chain.name),
            R.string.localizable.unlock_web3_account_agreement_2(chain.name),
        ]
        if WalletConnectService.evmChains.contains(chain) {
            let otherEVMChains = WalletConnectService.evmChains
                .subtracting([chain])
                .prefix(2)
                .map(\.name)
            if otherEVMChains.count == 2 {
                let line = R.string.localizable.unlock_web3_account_agreement_3(chain.name, otherEVMChains[0], otherEVMChains[1])
                lines.append(line)
            }
        }
        tableFooterView.setText(preface: R.string.localizable.unlock_web3_account_agreement(), bulletLines: lines)
        tableView.tableFooterView = tableFooterView
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        layoutTableFooterView()
    }
    
    override func loadInitialTrayView(animated: Bool) {
        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                 leftAction: #selector(close(_:)),
                                 rightTitle: R.string.localizable.unlock(),
                                 rightAction: #selector(confirm(_:)),
                                 animation: animated ? .vertical : nil)
    }
    
    override func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true) { [onDismiss, isUnlocked] in
            onDismiss?(isUnlocked)
        }
    }
    
    override func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss?(isUnlocked)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = R.string.localizable.unlocking()
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached {
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                let address = try EthereumAccount(keyStorage: keyStorage).address.toChecksumAddress()
                PropertiesDAO.shared.set(address, forKey: .evmAccount)
                await MainActor.run {
                    self.isUnlocked = true
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.tableHeaderView.titleLabel.text = R.string.localizable.unlock_web3_account_success()
                    self.reloadData(with: [
                        .info(caption: .account, content: address)
                    ])
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadSingleButtonTrayView(title: R.string.localizable.done(),
                                                  action:  #selector(self.close(_:)))
                }
            } catch {
                Logger.web3.warn(category: "Unlock", message: "\(error)")
                await MainActor.run {
                    self.isUnlocked = false
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .failure)
                    self.layoutTableHeaderView(title: R.string.localizable.unlock_web3_account_failed(),
                                               subtitle: error.localizedDescription)
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: R.string.localizable.retry(),
                                                  rightAction: #selector(self.confirm(_:)),
                                                  animation: .vertical)
                }
            }
        }
    }
    
}
