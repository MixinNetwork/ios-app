import UIKit
import GRDB
import MixinServices
import SnapKit

final class SearchCategoryViewController: UIViewController, HomeSearchViewController {
    
    enum Category {
        
        case asset
        case user
        case conversationsByName
        case conversationsByMessage
        
        var title: String {
            switch self {
            case .asset:
                return R.string.localizable.assets()
            case .user:
                return R.string.localizable.contact_title()
            case .conversationsByName:
                return R.string.localizable.conversations()
            case .conversationsByMessage:
                return R.string.localizable.messages()
            }
        }
        
    }
    
    var searchTextField: UITextField! {
        searchBoxView.textField
    }
    
    private let category: Category
    private let inheritedKeyword: String?
    private let searchBoxView = SearchBoxView()
    private let cancelButton = SearchCancelButton()
    private let queue = OperationQueue()
    
    private weak var tableView: UITableView!
    
    private var lastKeyword: String?
    private var models = [[Any]]()
    private var snapshot: DatabaseSnapshot?
    
    init(category: Category, keyword: String?) {
        self.category = category
        self.inheritedKeyword = keyword
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        cancelOperation()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = R.color.background_secondary()
        
        let topView = UIView()
        topView.backgroundColor = R.color.background()
        view.addSubview(topView)
        topView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(10)
        }
        
        let tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(topView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        self.tableView = tableView
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .onDrag
        tableView.separatorStyle = .none
        tableView.rowHeight = 70
        
        queue.maxConcurrentOperationCount = 1
        navigationItem.title = ""
        navigationItem.titleView = searchBoxView
        navigationItem.rightBarButtonItem = {
            let item = UIBarButtonItem(customView: cancelButton)
            if #available(iOS 26.0, *) {
                item.hidesSharedBackground = true
            }
            return item
        }()
        cancelButton.addTarget(homeViewController, action: #selector(HomeViewController.cancelSearching(_:)), for: .touchUpInside)
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        searchTextField.delegate = self
        searchTextField.text = inheritedKeyword
        switch category {
        case .asset:
            tableView.register(R.nib.assetCell)
        case .user, .conversationsByName, .conversationsByMessage:
            tableView.register(R.nib.peerCell)
        }
        let headerFrame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 36)
        let headerView = SearchHeaderView(frame: headerFrame)
        headerView.label.text = category.title
        headerView.button.isHidden = true
        headerView.isFirstSection = true
        tableView.tableHeaderView = headerView
        tableView.dataSource = self
        tableView.delegate = self
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
        models.flatMap({ $0 })
            .compactMap({ $0 as? SearchResult })
            .forEach({ $0.updateTitleAndDescription() })
        tableView.reloadData()
    }
    
    @objc func searchAction(_ sender: Any) {
        cancelOperation()
        guard let keyword = trimmedKeyword else {
            models = []
            tableView.reloadData()
            lastKeyword = nil
            searchBoxView.isBusy = false
            return
        }
        guard keyword != lastKeyword else {
            return
        }
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
                models = TokenDAO.shared.search(
                    keyword: keyword,
                    includesZeroBalanceItems: false,
                    sorting: true,
                    limit: nil
                ).map { token in
                    AssetSearchResult(asset: token, keyword: keyword)
                }
            case .user:
                models = UserDAO.shared.getUsers(keyword: keyword, limit: nil)
                    .map { UserSearchResult(user: $0, keyword: keyword) }
            case .conversationsByName:
                models = ConversationDAO.shared.getGroupOrStrangerConversation(withNameLike: keyword, limit: nil)
                    .map { ConversationSearchResult(conversation: $0, keyword: keyword) }
            case .conversationsByMessage:
                self?.snapshot = try? UserDatabase.current.makeSnapshot()
                if let snapshot = self?.snapshot {
                    models = ConversationDAO.shared.getConversation(from: snapshot, with: keyword, limit: nil)
                } else {
                    models = []
                }
                self?.snapshot = nil
            }
            guard !op.isCancelled, self != nil else {
                return
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled, let weakSelf = self else {
                    return
                }
                weakSelf.models = [models]
                weakSelf.tableView.reloadData()
                weakSelf.lastKeyword = keyword
                weakSelf.searchBoxView.isBusy = false
            }
        }
        queue.addOperation(op)
        searchBoxView.isBusy = true
    }
    
    private func cancelOperation() {
        snapshot?.interrupt()
        snapshot = nil
        queue.cancelAllOperations()
    }
    
}

extension SearchCategoryViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension SearchCategoryViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if models.isEmpty {
            return 0
        } else {
            return models[section].count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = models[indexPath.section][indexPath.row]
        switch category {
        case .asset:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
            let asset = (model as! AssetSearchResult).asset
            cell.render(token: asset)
            return cell
        case .user, .conversationsByName, .conversationsByMessage:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            let result = model as! SearchResult
            cell.render(result: result)
            return cell
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return models.count
    }
    
}

extension SearchCategoryViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let model = models[indexPath.section][indexPath.row]
        switch category {
        case .asset:
            let asset = (model as! AssetSearchResult).asset
            pushTokenViewController(token: asset, source: "more_search")
        case .user, .conversationsByName, .conversationsByMessage:
            pushViewController(keyword: trimmedKeyword, result: model as! SearchResult)
        }
    }
    
}
