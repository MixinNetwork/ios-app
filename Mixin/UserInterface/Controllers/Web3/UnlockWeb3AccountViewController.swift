import UIKit
import MixinServices

class UnlockWeb3AccountViewController: AuthenticationPreviewViewController {
    
    enum GenerationError: Swift.Error {
        case mismatched
    }
    
    private(set) var isUnlocked = false
    
    private let category: Web3Chain.Category
    
    private var firstChainName: String {
        category.chains[0].name
    }
    
    private var subtitle: String {
        R.string.localizable.unlock_web3_account_description(firstChainName)
    }
    
    init(category: Web3Chain.Category) {
        self.category = category
        super.init(warnings: [])
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsSelection = false
        tableHeaderView.setIcon { imageView in
            imageView.image = R.image.crypto_wallet()
        }
        layoutTableHeaderView(title: R.string.localizable.unlock_web3_account(firstChainName), subtitle: subtitle)
        let tableFooterView = BulletDescriptionView()
        var lines = [
            R.string.localizable.unlock_web3_account_agreement_1(firstChainName),
            R.string.localizable.unlock_web3_account_agreement_2(firstChainName),
        ]
        if category.chains.count >= 3 {
            let line = R.string.localizable.unlock_web3_account_agreement_3(category.chains[0].name, category.chains[1].name, category.chains[2].name)
            lines.append(line)
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
    
    override func performAction(with pin: String) {
        Logger.web3.info(category: "Unlock", message: "Will unlock web3")
        canDismissInteractively = false
        tableHeaderView.setIcon(progress: .busy)
        tableHeaderView.titleLabel.text = R.string.localizable.unlocking()
        replaceTrayView(with: nil, animation: .vertical)
        Task.detached {
            do {
                let address = try await self.deriveAddress(pin: pin)
                await MainActor.run {
                    self.isUnlocked = true
                    self.canDismissInteractively = true
                    self.tableHeaderView.setIcon(progress: .success)
                    self.layoutTableHeaderView(title: R.string.localizable.unlock_web3_account_success(), subtitle: self.subtitle)
                    self.reloadData(with: [
                        .info(caption: .account, content: address)
                    ])
                    self.tableView.tableFooterView = nil
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
                                               subtitle: error.localizedDescription,
                                               style: .destructive)
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
    
    func deriveAddress(pin: String) async throws -> String {
        fatalError("Must override")
    }
    
}
