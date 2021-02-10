import UIKit
import MixinServices

class WalletSearchResultsViewController: WalletSearchTableViewController {
    
    let activityIndicator = ActivityIndicatorView()
    
    private let queue = OperationQueue()
    
    private var searchResults: [AssetItem] = []
    private var lastKeyword: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        activityIndicator.tintColor = .accessoryText
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
        op.addExecutionBlock { [unowned op] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            
            let lowercasedKeyword = keyword.lowercased()
            let defaultIconUrl = "https://images.mixin.one/yH_I5b0GiV2zDmvrXRyr3bK5xusjfy5q7FX3lw3mM2Ryx4Dfuj6Xcw8SHNRnDKm7ZVE3_LvpKlLdcLrlFQUBhds=s128"
            func assetSorting(_ one: AssetItem, _ another: AssetItem) -> Bool {
                let oneSymbolEqualsToKeyword = one.symbol.lowercased() == lowercasedKeyword
                let anotherSymbolEqualsToKeyword = another.symbol.lowercased() == lowercasedKeyword
                if oneSymbolEqualsToKeyword && !anotherSymbolEqualsToKeyword {
                    return true
                } else if !oneSymbolEqualsToKeyword && anotherSymbolEqualsToKeyword {
                    return false
                }
                
                let oneCapitalization = one.balance.doubleValue * one.priceUsd.doubleValue
                let anotherCapitalization = another.balance.doubleValue * another.priceUsd.doubleValue
                if oneCapitalization != anotherCapitalization {
                    return oneCapitalization > anotherCapitalization
                }
                
                let oneHasIcon = one.iconUrl != defaultIconUrl
                let anotherHasIcon = another.iconUrl != defaultIconUrl
                if oneHasIcon && !anotherHasIcon {
                    return true
                } else if !oneHasIcon && anotherHasIcon {
                    return false
                }
                
                return one.name < another.name
            }
            
            var localItems = AssetDAO.shared
                .getAssets(keyword: keyword, sortResult: false, limit: nil)
                .sorted(by: assetSorting)
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                self.searchResults = localItems
                self.tableView.reloadData()
                self.tableView.removeEmptyIndicator()
            }
            
            let remoteAssets: [Asset]
            switch AssetAPI.search(keyword: keyword) {
            case .success(let assets):
                remoteAssets = assets
            case .failure:
                DispatchQueue.main.sync {
                    self.activityIndicator.stopAnimating()
                }
                return
            }
            
            localItems = localItems.filter{ $0.balance.doubleValue > 0 }
            let localIds = Set(localItems.map(\.assetId))
            let remoteItems = remoteAssets.compactMap({ (asset) -> AssetItem? in
                guard !localIds.contains(asset.assetId) else {
                    return nil
                }
                guard let chainAsset = AssetDAO.shared.getAsset(assetId: asset.chainId) else {
                    return nil
                }
                let chainInfo = AssetItem.ChainInfo(iconUrl: chainAsset.iconUrl,
                                                    name: chainAsset.name,
                                                    symbol: chainAsset.symbol)
                let item = AssetItem(asset: asset, chain: chainInfo)
                return item
            })
            
            let allItems: [AssetItem]?
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
                                          text: R.string.localizable.no_result(),
                                          photo: R.image.emptyIndicator.ic_search_result()!)
                self.activityIndicator.stopAnimating()
            }
        }
        queue.addOperation(op)
    }
    
}

extension WalletSearchResultsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        let item = searchResults[indexPath.row]
        cell.render(asset: item)
        return cell
    }
    
}

extension WalletSearchResultsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = searchResults[indexPath.row]
        let vc = AssetViewController.instance(asset: item)
        navigationController?.pushViewController(vc, animated: true)
        DispatchQueue.global().async {
            AppGroupUserDefaults.User.insertAssetSearchHistory(with: item.assetId)
            guard !AssetDAO.shared.isExist(assetId: item.assetId) else {
                return
            }
            AssetDAO.shared.insertOrUpdateAssets(assets: [item])
        }
    }
    
}
