import UIKit
import MixinServices

final class ExploreSearchCategoryViewController: UIViewController, ExploreSearchViewController {
    
    enum Category {
        case asset
        case bot
    }
    
    let cancelButton = SearchCancelButton()
    
    var wantsNavigationSearchBox: Bool {
        true
    }
    
    var navigationSearchBoxInsets: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: backButtonWidth, bottom: 0, right: cancelButton.frame.width + cancelButtonRightMargin)
    }
    
    private let category: Category
    private let queue = OperationQueue()
    
    private var lastKeyword: String?
    private var lastSearchFieldText: String?
    private var models: [Any] = []
    
    private weak var tableView: UITableView!
    
    init(category: Category) {
        self.category = category
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = ""
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
        
        let tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.backgroundColor = R.color.background()!
        tableView.keyboardDismissMode = .onDrag
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        switch category {
        case .asset:
            tableView.register(R.nib.marketCoinCell)
        case .bot:
            tableView.register(R.nib.peerCell)
        }
        tableView.tableHeaderView = {
            let headerFrame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 36)
            let headerView = SearchHeaderView(frame: headerFrame)
            headerView.label.text = switch category {
            case .asset:
                R.string.localizable.assets()
            case .bot:
                R.string.localizable.bots_title()
            }
            headerView.button.isHidden = true
            headerView.isFirstSection = true
            return headerView
        }()
        tableView.dataSource = self
        tableView.delegate = self
        
        queue.maxConcurrentOperationCount = 1
        searchAction(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        navigationSearchBoxView.isBusy = !queue.operations.isEmpty
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTextField.resignFirstResponder()
        searchTextField.removeTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        models.compactMap({ $0 as? SearchResult })
            .forEach({ $0.updateTitleAndDescription() })
        tableView.reloadData()
    }
    
    @objc private func searchAction(_ sender: Any) {
        queue.cancelAllOperations()
        guard let keyword = trimmedKeyword else {
            models = []
            tableView.reloadData()
            tableView.tableHeaderView?.isHidden = true
            tableView.removeEmptyIndicator()
            lastKeyword = nil
            navigationSearchBoxView.isBusy = false
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        navigationSearchBoxView.isBusy = true
        let category = self.category
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            usleep(200 * 1000)
            guard !op.isCancelled, self != nil else {
                return
            }
            let models: [Any]
            switch category {
            case .asset:
                models = MarketDAO.shared.markets(keyword: keyword, limit: nil)
            case .bot:
                models = UserDAO.shared.getAppUsers(keyword: keyword, limit: nil)
                    .map { user in UserSearchResult(user: user, keyword: keyword) }
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled, let self else {
                    return
                }
                self.models = models
                self.tableView.reloadData()
                self.tableView.checkEmpty(
                    dataCount: models.count,
                    text: R.string.localizable.no_results(),
                    photo: R.image.emptyIndicator.ic_search_result()!
                )
                self.tableView.tableHeaderView?.isHidden = models.isEmpty
                self.lastKeyword = keyword
                self.navigationSearchBoxView?.isBusy = false
            }
        }
        queue.addOperation(op)
    }
    
}

extension ExploreSearchCategoryViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        models.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = models[indexPath.row]
        switch category {
        case .asset:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.market_coin, for: indexPath)!
            let market = model as! FavorableMarket
            cell.load(market: market)
            return cell
        case .bot:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            let result = model as! SearchResult
            cell.render(result: result)
            cell.peerInfoView.avatarImageView.hasShadow = false
            return cell
        }
    }
    
}

extension ExploreSearchCategoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = models[indexPath.row]
        switch category {
        case .asset:
            let market = model as! FavorableMarket
            pushMarketViewController(market: market)
        case .bot:
            let result = models[indexPath.row] as! UserSearchResult
            pushConversationViewController(userItem: result.user)
        }
    }
    
}
