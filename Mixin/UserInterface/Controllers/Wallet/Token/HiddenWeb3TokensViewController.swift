import UIKit
import MixinServices

final class HiddenWeb3TokensViewController: HiddenTokensViewController {
    
    private let wallet: Web3Wallet
    private let availability: Web3Wallet.Availability
    
    private var tokens: [Web3TokenItem] = []
    
    init(wallet: Web3Wallet, availability: Web3Wallet.Availability) {
        self.wallet = wallet
        self.availability = availability
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.hidden_assets(),
            wallet: .common(wallet)
        )
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: Web3TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        reloadData()
    }
    
    @objc private func reloadData() {
        let walletID = wallet.walletID
        DispatchQueue.global().async { [weak self] in
            let tokens = Web3TokenDAO.shared.hiddenTokens(walletID: walletID)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.tokens = tokens
                self.tableView.reloadData()
                self.tableView.checkEmpty(
                    dataCount: tokens.count,
                    text: R.string.localizable.no_hidden_assets(),
                    photo: R.image.emptyIndicator.ic_hidden_assets()!
                )
            }
        }
    }
    
}

extension HiddenWeb3TokensViewController: UITableViewDataSource {
    
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

extension HiddenWeb3TokensViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = tokens[indexPath.row]
        let viewController = Web3TokenViewController(
            wallet: wallet,
            token: token,
            availability: availability
        )
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(
            style: .destructive,
            title: R.string.localizable.show()
        ) { [weak self, walletID=wallet.walletID] (action, _, completion) in
            guard let self = self else {
                return
            }
            let token = self.tokens.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            DispatchQueue.global().async {
                Web3TokenExtraDAO.shared.unhide(walletID: walletID, assetID: token.assetID)
            }
            completion(true)
        }
        action.backgroundColor = .theme
        return UISwipeActionsConfiguration(actions: [action])
    }
    
}
