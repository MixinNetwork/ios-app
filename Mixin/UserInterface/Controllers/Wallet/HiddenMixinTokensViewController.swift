import UIKit
import MixinServices

final class HiddenMixinTokensViewController: HiddenTokensViewController {
    
    private var tokens: [MixinTokenItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = WalletIdentifyingNavigationTitleView(
            title: R.string.localizable.hidden_assets(),
            wallet: .privacy
        )
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadData),
            name: TokenExtraDAO.tokenVisibilityDidChangeNotification,
            object: nil
        )
        reloadData()
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let tokens = TokenDAO.shared.hiddenTokens()
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

extension HiddenMixinTokensViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = tokens[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(token: token)
        return cell
    }
    
}

extension HiddenMixinTokensViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = tokens[indexPath.row]
        let viewController = MixinTokenViewController(token: token)
        navigationController?.pushViewController(viewController, animated: true)
        reporter.report(event: .assetDetail, tags: ["wallet": "main", "source": "hidden_assets"])
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: R.string.localizable.show()) { [weak self] (action, _, completion) in
            guard let self = self else {
                return
            }
            let token = self.tokens.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            DispatchQueue.global().async {
                let extra = TokenExtra(
                    assetID: token.assetID,
                    kernelAssetID: token.kernelAssetID,
                    isHidden: false,
                    balance: token.balance,
                    updatedAt: Date().toUTCString()
                )
                TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
            }
            completion(true)
        }
        action.backgroundColor = .theme
        return UISwipeActionsConfiguration(actions: [action])
    }
    
}
