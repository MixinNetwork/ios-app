import UIKit
import MixinServices

class TokenSearchResultsViewController: WalletSearchTableViewController {
    
    let activityIndicator = ActivityIndicatorView()
    
    var searchResults: [MixinTokenItem] = []
    var lastKeyword: String?
    
    private let queue = OperationQueue()
    private let supportedChainIDs: Set<String>?
    
    init(supportedChainIDs: Set<String>? = nil) {
        self.supportedChainIDs = supportedChainIDs
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        activityIndicator.tintColor = R.color.text_tertiary()!
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-23)
        }
    }
    
    func update(with keyword: String) {
        guard keyword != lastKeyword else {
            return
        }
        lastKeyword = keyword
        queue.cancelAllOperations()
        guard !keyword.isEmpty else {
            searchResults = []
            tableView.reloadData()
            tableView.removeEmptyIndicator()
            activityIndicator.stopAnimating()
            return
        }
        activityIndicator.startAnimating()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, supportedChainIDs] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            
            let lowercasedKeyword = keyword.lowercased()
            let defaultIconUrl = "https://images.mixin.one/yH_I5b0GiV2zDmvrXRyr3bK5xusjfy5q7FX3lw3mM2Ryx4Dfuj6Xcw8SHNRnDKm7ZVE3_LvpKlLdcLrlFQUBhds=s128"
            func assetSorting(_ one: MixinTokenItem, _ another: MixinTokenItem) -> Bool {
                let oneSymbolEqualsToKeyword = one.symbol.lowercased() == lowercasedKeyword
                let anotherSymbolEqualsToKeyword = another.symbol.lowercased() == lowercasedKeyword
                if oneSymbolEqualsToKeyword && !anotherSymbolEqualsToKeyword {
                    return true
                } else if !oneSymbolEqualsToKeyword && anotherSymbolEqualsToKeyword {
                    return false
                }
                
                let oneCapitalization = one.decimalBalance * one.decimalUSDPrice
                let anotherCapitalization = another.decimalBalance * another.decimalUSDPrice
                if oneCapitalization != anotherCapitalization {
                    return oneCapitalization > anotherCapitalization
                }
                
                let oneHasIcon = one.iconURL != defaultIconUrl
                let anotherHasIcon = another.iconURL != defaultIconUrl
                if oneHasIcon && !anotherHasIcon {
                    return true
                } else if !oneHasIcon && anotherHasIcon {
                    return false
                }
                
                return one.name < another.name
            }
            
            var localItems = TokenDAO.shared
                .search(keyword: keyword, sortResult: false, limit: nil)
                .sorted(by: assetSorting)
            if let ids = supportedChainIDs {
                localItems = localItems.filter { item in
                    ids.contains(item.chainID)
                }
            }
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                self.searchResults = localItems
                self.tableView.reloadData()
                self.tableView.removeEmptyIndicator()
            }
            
            let remoteAssets: [MixinToken]
            switch AssetAPI.search(keyword: keyword) {
            case .success(var assets):
                if let ids = supportedChainIDs {
                    assets = assets.filter { asset in
                        ids.contains(asset.chainID)
                    }
                }
                remoteAssets = assets
            case .failure:
                DispatchQueue.main.sync {
                    self.activityIndicator.stopAnimating()
                }
                return
            }
            
            localItems = localItems.filter{ $0.balance.doubleValue > 0 }
            let localIds = Set(localItems.map(\.assetID))
            let remoteItems = remoteAssets.compactMap({ (token) -> MixinTokenItem? in
                guard !localIds.contains(token.assetID) else {
                    return nil
                }
                let chain: Chain
                if let localChain = ChainDAO.shared.chain(chainId: token.chainID) {
                    chain = localChain
                } else if case let .success(remoteChain) = AssetAPI.chain(chainId: token.chainID) {
                    DispatchQueue.global().async {
                        ChainDAO.shared.save([remoteChain])
                        Web3ChainDAO.shared.save([remoteChain])
                    }
                    chain = remoteChain
                } else {
                    return nil
                }
                let item = MixinTokenItem(token: token, balance: "0", isHidden: false, chain: chain)
                return item
            })
            
            let allItems: [MixinTokenItem]?
            if remoteItems.isEmpty {
                allItems = nil
            } else {
                allItems = (localItems + remoteItems).sorted(by: assetSorting)
            }
            guard !op.isCancelled else {
                return
            }
            
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                if let items = allItems {
                    self.searchResults = items
                    self.tableView.reloadData()
                }
                self.tableView.checkEmpty(dataCount: self.searchResults.count,
                                          text: R.string.localizable.no_results(),
                                          photo: R.image.emptyIndicator.ic_search_result()!)
                self.activityIndicator.stopAnimating()
            }
        }
        queue.addOperation(op)
    }
    
}

extension TokenSearchResultsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        let item = searchResults[indexPath.row]
        cell.render(token: item, style: .symbolWithName)
        return cell
    }
    
}

extension TokenSearchResultsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = searchResults[indexPath.row]
        if let parent = self.parent as? WalletSearchViewController {
            parent.delegate?.walletSearchViewController(parent, didSelectToken: item)
        }
        DispatchQueue.global().async {
            AppGroupUserDefaults.User.insertAssetSearchHistory(with: item.assetID)
        }
    }
    
}
