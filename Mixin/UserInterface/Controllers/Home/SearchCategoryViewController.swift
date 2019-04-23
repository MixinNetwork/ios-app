import UIKit

class SearchCategoryViewController: UIViewController, SearchableViewController {
    
    enum Category {
        case asset
        case contact
        case group
        case conversation
    }
    
    @IBOutlet weak var tableView: UITableView!
    
    let titleView = R.nib.searchTitleView(owner: nil)!
    
    var category = Category.asset
    var inheritedKeyword = ""
    var lastKeyword = ""
    
    var searchTextField: UITextField {
        return titleView.searchBoxView.textField
    }
    
    private let queue = OperationQueue()
    
    private var models = [[Any]]()
    
    deinit {
        queue.cancelAllOperations()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        titleView.searchBoxLeadingConstraint.constant = 0
        titleView.cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        searchTextField.text = inheritedKeyword
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        searchTextField.delegate = self
        navigationItem.titleView = titleView
        switch category {
        case .asset:
            tableView.register(R.nib.assetCell)
        case .contact, .group, .conversation:
            tableView.register(R.nib.searchResultCell)
        }
        tableView.dataSource = self
        tableView.delegate = self
        searchAction(self)
    }
    
    @objc func searchAction(_ sender: Any) {
        let keyword = self.trimmedLowercaseKeyword
        queue.cancelAllOperations()
        guard keyword != lastKeyword else {
            return
        }
        guard !keyword.isEmpty else {
            models = []
            tableView.reloadData()
            return
        }
        let category = self.category
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            let models: [Any]
            switch category {
            case .asset:
                models = AssetDAO.shared.getAssets(keyword: keyword, limit: nil)
                    .map { AssetSearchResult(asset: $0, keyword: keyword) }
            case .contact:
                models = UserDAO.shared.getUsers(keyword: keyword, limit: nil)
                    .map { SearchResult(user: $0, keyword: keyword) }
            case .group:
                models = ConversationDAO.shared.getGroupConversation(nameLike: keyword, limit: nil)
                    .map { SearchResult(group: $0, keyword: keyword) }
            case .conversation:
                models = ConversationDAO.shared.getConversation(withMessageLike: keyword, limit: nil)
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
            }
        }
        queue.addOperation(op)
    }
    
    @objc func cancelAction() {
        navigationController?.popViewController(animated: true)
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
        case .contact, .group, .conversation:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.search_result, for: indexPath)!
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
        case .contact, .group, .conversation:
            pushViewController(keyword: trimmedLowercaseKeyword,
                               result: model as! SearchResult)
        }
    }
    
}
