import UIKit
import MixinServices

final class ExploreSearchCategoryViewController: UIViewController, ExploreSearchViewController {
    
    enum Category {
        case asset
        case bot
    }
    
    var searchTextField: UITextField! {
        searchBoxView.textField
    }
    
    private let category: Category
    private let inheritedKeyword: String?
    private let queue = OperationQueue()
    private let searchBoxView = SearchBoxView()
    
    private weak var tableView: UITableView!
    
    private var lastKeyword: String?
    private var models: [Any] = []
    
    init(category: Category, keyword: String?) {
        self.category = category
        self.inheritedKeyword = keyword
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.titleView = searchBoxView
        navigationItem.rightBarButtonItem = .cancelSearch(
            target: exploreViewController,
            action: #selector(ExploreViewController.cancelSearching(_:)),
        )
        searchBoxView.textField.delegate = self
        searchBoxView.textField.rightViewMode = .always
        searchTextField.addTarget(
            self,
            action: #selector(searchAction(_:)),
            for: .editingChanged
        )
        searchTextField.text = inheritedKeyword
        
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
            tableView.register(R.nib.assetCell)
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTextField.resignFirstResponder()
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
            searchBoxView.isBusy = false
            return
        }
        guard keyword != lastKeyword else {
            return
        }
        searchBoxView.isBusy = true
        let category = self.category
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            Thread.sleep(forTimeInterval: 0.5)
            guard !op.isCancelled, self != nil else {
                return
            }
            let models: [Any]
            switch category {
            case .asset:
                models = TokenDAO.shared.search(
                    keyword: keyword,
                    includesZeroBalanceItems: false,
                    sorting: true,
                    limit: nil
                ).map { token in
                    AssetSearchResult(asset: token, keyword: keyword)
                }
            case .bot:
                models = UserDAO.shared.getAppUsers(keyword: keyword, limit: nil)
                    .map { user in UserSearchResult(user: user, keyword: keyword) }
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled, let self else {
                    return
                }
                self.models = models
                self.reloadTableViewData(showEmptyIndicatorIfEmpty: false)
                self.lastKeyword = keyword
                self.searchBoxView.isBusy = false
            }
        }
        queue.addOperation(op)
    }
    
    private func reloadTableViewData(showEmptyIndicatorIfEmpty: Bool) {
        tableView.reloadData()
        if showEmptyIndicatorIfEmpty {
            tableView.checkEmpty(
                dataCount: models.count,
                text: R.string.localizable.no_results(),
                photo: R.image.emptyIndicator.ic_search_result()!
            )
        } else {
            tableView.removeEmptyIndicator()
        }
        tableView.tableHeaderView?.isHidden = models.isEmpty
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
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
            let result = model as! AssetSearchResult
            cell.render(token: result.asset, attributedSymbol: result.attributedSymbol)
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
        searchTextField.resignFirstResponder()
        let model = models[indexPath.row]
        switch category {
        case .asset:
            let result = model as! AssetSearchResult
            pushTokenViewController(token: result.asset)
        case .bot:
            let result = models[indexPath.row] as! UserSearchResult
            pushConversationViewController(userItem: result.user)
        }
    }
    
}

extension ExploreSearchCategoryViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}
