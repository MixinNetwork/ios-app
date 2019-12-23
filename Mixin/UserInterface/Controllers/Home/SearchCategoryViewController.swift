import UIKit
import WCDBSwift
import MixinServices

class SearchCategoryViewController: UIViewController, HomeSearchViewController {
    
    enum Category {
        case asset
        case user
        case conversationsByName
        case conversationsByMessage
        
        var title: String {
            switch self {
            case .asset:
                return R.string.localizable.search_section_title_asset()
            case .user:
                return R.string.localizable.search_section_title_user()
            case .conversationsByName:
                return R.string.localizable.search_section_title_conversation_by_name()
            case .conversationsByMessage:
                return R.string.localizable.search_section_title_conversation_by_message()
            }
        }
    }
    
    @IBOutlet weak var tableView: UITableView!
    
    let cancelButton = SearchCancelButton()
    
    var category = Category.asset
    
    var wantsNavigationSearchBox: Bool {
        return true
    }
    
    var navigationSearchBoxInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: backButtonWidth, bottom: 0, right: cancelButton.frame.width + cancelButtonRightMargin)
    }
    
    private let queue = OperationQueue()
    
    private var lastKeyword: String?
    private var lastSearchFieldText: String?
    private var models = [[Any]]()
    private var statement: CoreStatement?
    
    deinit {
        cancelOperation()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        navigationItem.title = " "
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
        cancelButton.addTarget(homeViewController, action: #selector(HomeViewController.hideSearch), for: .touchUpInside)
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        searchTextField.delegate = self
        switch category {
        case .asset:
            tableView.register(R.nib.assetCell)
        case .user, .conversationsByName, .conversationsByMessage:
            tableView.register(R.nib.peerCell)
        }
        let headerFrame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 36)
        let headerView = SearchHeaderView(frame: headerFrame)
        headerView.label.text = category.title
        headerView.button.isHidden = true
        headerView.isFirstSection = true
        tableView.tableHeaderView = headerView
        tableView.dataSource = self
        tableView.delegate = self
        searchAction(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        navigationSearchBoxView.isBusy = !queue.operations.isEmpty
        if let text = lastSearchFieldText {
            searchTextField.text = text
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTextField.resignFirstResponder()
        searchTextField.removeTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        lastSearchFieldText = searchTextField.text
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
        guard let keyword = trimmedLowercaseKeyword else {
            models = []
            tableView.reloadData()
            lastKeyword = nil
            navigationSearchBoxView.isBusy = false
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
                models = AssetDAO.shared.getAssets(keyword: keyword, limit: nil)
                    .map { AssetSearchResult(asset: $0, keyword: keyword) }
            case .user:
                models = UserDAO.shared.getUsers(keyword: keyword, limit: nil)
                    .map { UserSearchResult(user: $0, keyword: keyword) }
            case .conversationsByName:
                models = ConversationDAO.shared.getGroupOrStrangerConversation(withNameLike: keyword, limit: nil)
                    .map { ConversationSearchResult(conversation: $0, keyword: keyword) }
            case .conversationsByMessage:
                models = ConversationDAO.shared.getConversation(withMessageLike: keyword, limit: nil, callback: { (statement) in
                    guard !op.isCancelled else {
                        return
                    }
                    self?.statement = statement
                })
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
                weakSelf.navigationSearchBoxView?.isBusy = false
            }
        }
        queue.addOperation(op)
        navigationSearchBoxView.isBusy = true
    }
    
    private func cancelOperation() {
        statement?.interrupt()
        statement = nil
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
            cell.render(asset: asset)
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
            pushAssetViewController(asset: asset)
        case .user, .conversationsByName, .conversationsByMessage:
            pushViewController(keyword: trimmedLowercaseKeyword, result: model as! SearchResult)
        }
    }
    
}
