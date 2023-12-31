import UIKit
import MixinServices

final class WalletSearchRecommendationViewController: WalletSearchTableViewController {
    
    private enum ReuseId {
        static let header = "header"
        static let footer = "footer"
    }
    
    private enum Section: Int, CaseIterable {
        case history = 0
        case trending
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.WalletSearchRecommendation")
    
    private var history: [TokenItem] = []
    private var trending: [AssetItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(SearchHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(SearchFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.dataSource = self
        tableView.delegate = self
        
        queue.async { [weak self] in
            let history = AppGroupUserDefaults.User.assetSearchHistory
                .compactMap(TokenDAO.shared.tokenItem(with:))
            let trending = TopAssetsDAO.shared.getAssets()
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.history = history
                self.trending = trending
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
            }
        }
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadTrending),
                                               name: TopAssetsDAO.didChangeNotification,
                                               object: nil)
        ConcurrentJobQueue.shared.addJob(job: RefreshTopAssetsJob())
    }
    
    @objc private func reloadTrending() {
        let trendingSection = IndexSet(arrayLiteral: Section.trending.rawValue)
        queue.async { [weak self] in
            let trending = TopAssetsDAO.shared.getAssets()
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.trending = trending
                self.tableView.reloadSections(trendingSection, with: .none)
            }
        }
    }
    
}

extension WalletSearchRecommendationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .history:
            return history.count
        case .trending:
            return trending.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        switch Section(rawValue: indexPath.section)! {
        case .history:
            let item = history[indexPath.row]
            cell.render(token: item)
        case .trending:
            let item = trending[indexPath.row]
            cell.render(asset: item)
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
}

extension WalletSearchRecommendationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .history where !history.isEmpty:
            return SearchHeaderView.height(isFirstSection: true)
        case .trending where !trending.isEmpty:
            return SearchHeaderView.height(isFirstSection: history.isEmpty)
        default:
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if Section(rawValue: section) == .history && !history.isEmpty {
            return SearchFooterView.height
        } else {
            return .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! SearchHeaderView
        switch Section(rawValue: section)! {
        case .history where !history.isEmpty:
            view.label.text = R.string.localizable.recent_searches()
        case .trending where !trending.isEmpty:
            view.label.text = R.string.localizable.trending()
        default:
            return nil
        }
        view.button.isHidden = true
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if Section(rawValue: section) == .history && !history.isEmpty {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer)!
            view.contentView.backgroundColor = .secondaryBackground
            return view
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .history:
            let item = history[indexPath.row]
            let viewController = TokenViewController.instance(token: item)
            navigationController?.pushViewController(viewController, animated: true)
        case .trending:
            let item = trending[indexPath.row]
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            queue.async {
                func pushTokenViewController(with token: TokenItem) {
                    DispatchQueue.main.sync {
                        hud.hide()
                        let viewController = TokenViewController.instance(token: token)
                        self.navigationController?.pushViewController(viewController, animated: true)
                    }
                }
                
                func reportError(_ error: Error) {
                    DispatchQueue.main.sync {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
                
                if let token = TokenDAO.shared.tokenItem(with: item.assetId) {
                    pushTokenViewController(with: token)
                } else {
                    let chainID = item.chainId
                    let chain: Chain
                    if let localChain = ChainDAO.shared.chain(chainId: chainID) {
                        chain = localChain
                    } else {
                        switch NetworkAPI.chain(id: chainID) {
                        case .success(let remoteChain):
                            chain = remoteChain
                            ChainDAO.shared.save([chain])
                        case .failure(let error):
                            reportError(error)
                            return
                        }
                    }
                    switch SafeAPI.assets(id: item.assetId) {
                    case .success(let token):
                        TokenDAO.shared.save(assets: [token])
                        let item = TokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                        pushTokenViewController(with: item)
                    case .failure(let error):
                        reportError(error)
                    }
                }
            }
        }
    }
    
}
