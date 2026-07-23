import UIKit
import GRDB
import MixinServices

final class SearchMarketViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    private let queue = OperationQueue()
    
    private var lastSearchFieldText: String?
    private var searchResults: [FavorableMarket] = []
    private var lastKeyword: String?
    
    private var trimmedKeyword: String? {
        guard let text = searchBoxView.textField.text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            return nil
        } else {
            return trimmed
        }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.addTarget(
            self,
            action: #selector(searchKeyword(_:)),
            for: .editingChanged
        )
        searchBoxView.textField.becomeFirstResponder()
        
        tableView.backgroundColor = R.color.background()!
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        tableView.register(R.nib.marketCoinCell)
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        
        queue.maxConcurrentOperationCount = 1
    }
    
    @IBAction func cancelSearching(_ sender: Any) {
        searchBoxView.textField.resignFirstResponder()
        (parent as? MarketDashboardViewController)?.cancelSearching(animated: true)
    }
    
    @objc private func searchKeyword(_ sender: Any) {
        guard let keyword = trimmedKeyword?.lowercased() else {
            queue.cancelAllOperations()
            lastKeyword = nil
            searchBoxView.isBusy = false
            tableView.reloadData()
            return
        }
        guard keyword != lastKeyword else {
            searchBoxView.isBusy = false
            return
        }
        queue.cancelAllOperations()
        searchBoxView.isBusy = true
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            Thread.sleep(forTimeInterval: 0.5)
            guard !op.isCancelled else {
                return
            }
            let localSearchResults = MarketDAO.shared.markets(keyword: keyword, limit: nil)
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                self.lastKeyword = keyword
                self.searchResults = localSearchResults
                self.reloadTableViewData(showEmptyIndicatorIfEmpty: false)
                self.searchBoxView.isBusy = false
            }
            
            guard !op.isCancelled else {
                return
            }
            Logger.general.debug(category: "ExploreAggregatedSearch", message: "Search remote markets for: \(keyword)")
            RouteAPI.markets(keyword: keyword, queue: .global()) { result in
                switch result {
                case .failure:
                    break
                case .success(let markets):
                    MarketDAO.shared.save(markets: markets)
                    var remoteMarkets = markets.reduce(into: [:]) { results, market in
                        results[market.coinID] = market
                    }
                    let combinedSearchResults = localSearchResults.map { market in
                        if let remoteMarket = remoteMarkets.removeValue(forKey: market.coinID) {
                            FavorableMarket(market: remoteMarket, isFavorite: market.isFavorite)
                        } else {
                            market
                        }
                    } + remoteMarkets.values.map { market in
                        FavorableMarket(market: market, isFavorite: false)
                    }
                    DispatchQueue.main.async {
                        guard keyword == self.lastKeyword else {
                            return
                        }
                        Logger.general.debug(category: "ExploreAggregatedSearch", message: "Showing remote markets for: \(markets.map(\.symbol))")
                        self.searchResults = combinedSearchResults
                        self.reloadTableViewData(showEmptyIndicatorIfEmpty: true)
                    }
                }
            }
        }
        queue.addOperation(op)
    }
    
    private func reloadTableViewData(showEmptyIndicatorIfEmpty: Bool) {
        tableView.reloadData()
        if showEmptyIndicatorIfEmpty {
            tableView.checkEmpty(
                dataCount: searchResults.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
        } else {
            tableView.removeEmptyIndicator()
        }
    }
    
}

extension SearchMarketViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.market_coin, for: indexPath)!
        let result = searchResults[indexPath.row]
        cell.load(market: result)
        return cell
    }
    
}

extension SearchMarketViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchBoxView.textField.resignFirstResponder()
        let market = searchResults[indexPath.row]
        let controller = MarketViewController(market: market)
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
