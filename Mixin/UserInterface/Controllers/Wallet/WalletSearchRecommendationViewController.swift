import UIKit
import MixinServices

final class WalletSearchRecommendationViewController: WalletSearchTableViewController {
    
    private enum ReuseID {
        static let header = "h"
        static let footer = "f"
    }
    
    private enum Section: Int, CaseIterable {
        case history = 0
        case trending
    }
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.WalletSearchRecommendation")
    private let supportedChainIDs: Set<String>?
    
    private var history: [MixinTokenItem] = []
    private var trending: [AssetItem] = []
    
    init(supportedChainIDs: Set<String>? = nil) {
        self.supportedChainIDs = supportedChainIDs
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(
            SearchHeaderView.self,
            forHeaderFooterViewReuseIdentifier: ReuseID.header
        )
        tableView.register(
            SearchFooterView.self,
            forHeaderFooterViewReuseIdentifier: ReuseID.footer
        )
        tableView.dataSource = self
        tableView.delegate = self
        
        queue.async { [weak self, supportedChainIDs] in
            var history = AppGroupUserDefaults.User.assetSearchHistory
                .compactMap(TokenDAO.shared.tokenItem(assetID:))
            var trending = TopAssetsDAO.shared.getAssets()
            if let ids = supportedChainIDs {
                history = history.filter { item in
                    ids.contains(item.chainID)
                }
                trending = trending.filter { item in
                    ids.contains(item.chainId)
                }
            }
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
        queue.async { [weak self, supportedChainIDs] in
            var trending = TopAssetsDAO.shared.getAssets()
            if let ids = supportedChainIDs {
                trending = trending.filter { item in
                    ids.contains(item.chainId)
                }
            }
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
            cell.render(token: item, style: .symbolWithName)
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
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseID.header) as! SearchHeaderView
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
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseID.footer)!
            view.contentView.backgroundColor = .secondaryBackground
            return view
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let parent = self.parent as? WalletSearchViewController else {
            return
        }
        switch Section(rawValue: indexPath.section)! {
        case .history:
            let item = history[indexPath.row]
            parent.delegate?.walletSearchViewController(parent, didSelectToken: item)
        case .trending:
            let item = trending[indexPath.row]
            let hud = Hud()
            hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
            queue.async {
                func report(token: MixinTokenItem) {
                    DispatchQueue.main.sync {
                        hud.hide()
                        parent.delegate?.walletSearchViewController(parent, didSelectToken: token)
                    }
                }
                
                func report(error: Error) {
                    DispatchQueue.main.sync {
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
                
                if let token = TokenDAO.shared.tokenItem(assetID: item.assetId) {
                    report(token: token)
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
                            Web3ChainDAO.shared.save([chain])
                        case .failure(let error):
                            report(error: error)
                            return
                        }
                    }
                    switch SafeAPI.assets(id: item.assetId) {
                    case .success(let token):
                        TokenDAO.shared.save(assets: [token])
                        let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                        report(token: item)
                    case .failure(let error):
                        report(error: error)
                    }
                }
            }
        }
    }
    
}
