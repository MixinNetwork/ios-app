import UIKit
import MixinServices

final class WalletSearchResultsViewController<ModelController: WalletSearchModelController>: WalletSearchTableViewController, UITableViewDataSource, UITableViewDelegate {
    
    let activityIndicator = ActivityIndicatorView()
    
    var searchResults: [ModelController.Item] = []
    var lastKeyword: String?
    
    private let modelController: ModelController
    private let queue = OperationQueue()
    
    init(modelController: ModelController) {
        self.modelController = modelController
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
        op.addExecutionBlock { [unowned op, modelController] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            let comparator = TokenComparator<ModelController>(keyword: keyword)
            
            let localItems = modelController
                .localItems(keyword: keyword)
                .sorted(using: comparator)
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                self.searchResults = localItems
                self.tableView.reloadData()
                self.tableView.removeEmptyIndicator()
            }
            
            let remoteTokens: [MixinToken]
            switch AssetAPI.search(keyword: keyword) {
            case .success(let assets):
                remoteTokens = assets
            case .failure:
                DispatchQueue.main.sync {
                    guard !op.isCancelled else {
                        return
                    }
                    self.tableView.checkEmpty(
                        dataCount: self.searchResults.count,
                        text: R.string.localizable.no_results(),
                        photo: R.image.emptyIndicator.ic_search_result()!
                    )
                    self.activityIndicator.stopAnimating()
                }
                return
            }
            
            var allItems: [String: ModelController.Item] = modelController
                .remoteItems(from: remoteTokens)
                .reduce(into: [:]) { result, token in
                    result[token.assetID] = token
                }
            for item in localItems where allItems[item.assetID] == nil {
                allItems[item.assetID] = item
            }
            let sortedAllItems = allItems.values.sorted(using: comparator)
            
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                self.searchResults = sortedAllItems
                self.tableView.reloadData()
                self.tableView.checkEmpty(
                    dataCount: self.searchResults.count,
                    text: R.string.localizable.no_results(),
                    photo: R.image.emptyIndicator.ic_search_result()!
                )
                self.activityIndicator.stopAnimating()
            }
        }
        queue.addOperation(op)
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        let item = searchResults[indexPath.row]
        cell.render(token: item, style: .symbolWithName)
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = searchResults[indexPath.row]
        modelController.reportUserSelection(token: item)
        DispatchQueue.global().async {
            AppGroupUserDefaults.User.insertAssetSearchHistory(with: item.assetID)
        }
    }
    
}

fileprivate struct TokenComparator<ModelController: WalletSearchModelController>: SortComparator {
    
    var order: SortOrder = .forward
    
    private let lowercasedKeyword: String
    
    init(keyword: String) {
        self.lowercasedKeyword = keyword.lowercased()
    }
    
    func compare(_ lhs: ModelController.Item, _ rhs: ModelController.Item) -> ComparisonResult {
        let leftDeterminant = determinant(item: lhs)
        let rightDeterminant = determinant(item: rhs)
        let forwardResult: ComparisonResult = if leftDeterminant == rightDeterminant {
            lhs.name.compare(rhs.name)
        } else if leftDeterminant < rightDeterminant {
            .orderedDescending
        } else {
            .orderedAscending
        }
        return switch order {
        case .forward:
             forwardResult
        case .reverse:
            switch forwardResult {
            case .orderedAscending:
                    .orderedDescending
            case .orderedDescending:
                    .orderedAscending
            case .orderedSame:
                    .orderedSame
            }
        }
    }
    
    func determinant(item: ModelController.Item) -> (Int, Decimal, Decimal) {
        let lowercasedSymbol = item.symbol.lowercased()
        let symbolPriority = if lowercasedSymbol == lowercasedKeyword {
            2
        } else if lowercasedSymbol.contains(lowercasedKeyword) {
            1
        } else {
            0
        }
        return (
            symbolPriority,
            item.decimalBalance * item.decimalUSDPrice,
            item.decimalBalance,
        )
    }
    
}
