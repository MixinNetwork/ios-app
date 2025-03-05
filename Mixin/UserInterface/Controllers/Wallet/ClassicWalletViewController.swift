import UIKit
import MixinServices

final class ClassicWalletViewController: WalletViewController {
    
    private let walletID: String
    
    private var tokens: [Web3TokenItem] = []
    
    init(walletID: String) {
        self.walletID = walletID
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = R.string.localizable.classic_wallet()
        tableView.dataSource = self
        ConcurrentJobQueue.shared.addJob(job: RefreshWeb3TokenJob(walletID: walletID))
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadDataIfWalletMatch(_:)),
            name: Web3TokenDAO.tokensDidChangeNotification,
            object: nil
        )
        reloadData()
    }
    
    @objc private func reloadDataIfWalletMatch(_ notification: Notification) {
        guard let id = notification.userInfo?[Web3TokenDAO.walletIDUserInfoKey] as? String else {
            return
        }
        guard id == walletID else {
            return
        }
        reloadData()
    }
    
    private func reloadData() {
        DispatchQueue.global().async { [walletID, weak self] in
            let tokens = Web3TokenDAO.shared.tokens(walletID: walletID)
            let chainIDs = Set(tokens.map(\.chainID))
            let chains = ChainDAO.shared.chains(chainIDs: chainIDs)
            let items = tokens.map { token in
                Web3TokenItem(token: token, chain: chains[token.chainID])
            }
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                self.tokens = items
                self.tableHeaderView.reloadValues(tokens: tokens)
                self.layoutTableHeaderView()
                self.tableView.reloadData()
            }
        }
    }
    
}

extension ClassicWalletViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = tokens[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(web3Token: token)
        return cell
    }
    
}

extension ClassicWalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = tokens[indexPath.row]
        let viewController = Web3TokenViewController(token: token)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
}
