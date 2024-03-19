import UIKit
import web3
import MixinServices

final class CreateWeb3WalletViewController: AuthenticationPreviewViewController {
    
    private let chainName: String
    
    init(chainName: String) {
        self.chainName = chainName
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
        layoutTableHeaderView(title: "创建 \(chainName) 账户",
                              subtitle: "您的 \(chainName) 账户基于 Mixin Messenger  的 MPC 钱包并根据 BIP44 协议派生而来。")
        let tableFooterView = BulletDescriptionView()
        let lines = [
            "\(chainName) 账户与 Mixin 钱包资产隔离但使用同一个 PIN 进行资产管理。",
            "在 \(chainName) 账户与 Mixin 钱包之间划转资产需要支付网络矿工费。",
            "当您创建 \(chainName) 账户时，也将自动创建 Polygon、BSC 等 EVM 账户。",
        ]
        tableFooterView.setText(preface: "建议与去中心化应用程序交互完后尽快将资产转回更安全的 Mixin 钱包。",
                                bulletLines: lines)
        tableView.tableFooterView = tableFooterView
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        layoutTableFooterView()
    }
    
    override func loadInitialTrayView(animated: Bool) {
        loadDoubleButtonTrayView(leftTitle: R.string.localizable.cancel(),
                                 leftAction: #selector(close(_:)),
                                 rightTitle: R.string.localizable.create(),
                                 rightAction: #selector(confirm(_:)),
                                 animation: animated ? .vertical : nil)
    }
    
    override func performAction(with pin: String) {
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = "正在创建"
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached {
            do {
                let priv = try await TIP.web3WalletPrivateKey(pin: pin)
                let keyStorage = InPlaceKeyStorage(raw: priv)
                let address = try EthereumAccount(keyStorage: keyStorage).address.toChecksumAddress()
                PropertiesDAO.shared.set(address, forKey: .evmAccount)
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.tableHeaderView.titleLabel.text = "创建成功"
                    self.reloadData(with: [
                        .info(caption: .account, content: address)
                    ])
                    self.tableView.setContentOffset(.zero, animated: true)
                    self.loadDoubleButtonTrayView(leftTitle: R.string.localizable.close(),
                                                  leftAction: #selector(self.close(_:)),
                                                  rightTitle: "View",
                                                  rightAction: #selector(self.close(_:)),
                                                  animation: .vertical)
                }
            } catch {
                Logger.walletConnect.warn(category: "CreateWeb3Wallet", message: "Failed to create: \(error)")
                await MainActor.run {
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .failure)
                    self.layoutTableHeaderView(title: "创建失败",
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
