import UIKit
import MixinServices

final class HiddenTokensViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    private var tokens = [MixinTokenItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.hide_asset()
        updateTableViewContentInset()
        tableView.register(R.nib.assetCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.reloadData()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadData), name: TokenExtraDAO.tokenVisibilityDidChangeNotification, object: nil)
        reloadData()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInset()
    }
    
    @objc private func reloadData() {
        DispatchQueue.global().async { [weak self] in
            let tokens = TokenDAO.shared.hiddenTokens()
            DispatchQueue.main.async {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.tokens = tokens
                weakSelf.tableView.reloadData()
                weakSelf.tableView.checkEmpty(dataCount: tokens.count,
                                              text: R.string.localizable.no_hidden_assets(),
                                              photo: R.image.emptyIndicator.ic_hidden_assets()!)
            }
        }
    }

    @IBAction func backAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    class func instance() -> UIViewController {
        R.storyboard.wallet.hidden_assets()!
    }
    
    private func updateTableViewContentInset() {
        if view.safeAreaInsets.bottom < 1 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
}

extension HiddenTokensViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = tokens[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        cell.render(asset: token)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        navigationController?.pushViewController(TokenViewController(token: tokens[indexPath.row]), animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: R.string.localizable.show()) { [weak self] (action, _, completion) in
            guard let self = self else {
                return
            }
            let token = self.tokens.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            DispatchQueue.global().async {
                let extra = TokenExtra(assetID: token.assetID,
                                       kernelAssetID: token.kernelAssetID,
                                       isHidden: false,
                                       balance: token.balance,
                                       updatedAt: Date().toUTCString())
                TokenExtraDAO.shared.insertOrUpdateHidden(extra: extra)
            }
            completion(true)
        }
        action.backgroundColor = .theme
        return UISwipeActionsConfiguration(actions: [action])
    }
    
}
