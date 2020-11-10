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
            make.bottom.equalToSuperview().offset(-16)
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
            
            let localAssets = AssetDAO.shared.getAssets(keyword: keyword, limit: nil)
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                self.searchResults = localAssets
                self.tableView.reloadData()
                self.tableView.removeEmptyIndicator()
            }
            
            let remoteAssets: [Asset]
            switch AssetAPI.search(keyword: keyword) {
            case .success(let assets):
                remoteAssets = assets
            case .failure:
                remoteAssets = []
            }
            let localIds = Set(localAssets.map(\.assetId))
            let remoteItems = remoteAssets.compactMap({ (asset) -> AssetItem? in
                guard !localIds.contains(asset.assetId) else {
                    return nil
                }
                guard let chainAsset = AssetDAO.shared.getAsset(assetId: asset.chainId) else {
                    return nil
                }
                let item = AssetItem(asset: asset,
                                     chainIconUrl: chainAsset.iconUrl,
                                     chainName: chainAsset.name,
                                     chainSymbol: chainAsset.symbol)
                return item
            })
            
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                if !remoteItems.isEmpty {
                    self.searchResults.append(contentsOf: remoteItems)
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
            let asset = Asset(item: item)
            AssetDAO.shared.insertOrUpdateAssets(assets: [asset])
        }
    }
    
}
