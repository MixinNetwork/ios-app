import UIKit
import GRDB
import MixinServices

final class ExploreSearchViewController: UIViewController {
    
    private enum Content {
        case recentApps
        case searchResult
    }
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    private let queue = OperationQueue()
    private let initDataOperation = BlockOperation()
    
    private var allAppUsers: [User]? = nil
    private var recentAppUsers: [UserItem] = []
    private var searchResults: [AppUserSearchResult] = []
    private var content: Content = .recentApps
    private var lastKeyword: String?
    
    private var trimmedLowercaseKeyword: String? {
        guard let text = searchBoxView.textField.text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return nil
        }
        return trimmed.lowercased()
    }
    
    init(users: [User]?) {
        self.allAppUsers = users
        let nib = R.nib.exploreSearchView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.placeholder = R.string.localizable.setting_auth_search_hint()
        searchBoxView.textField.addTarget(self, action: #selector(searchKeyword(_:)), for: .editingChanged)
        searchBoxView.textField.becomeFirstResponder()
        searchBoxView.isBusy = true
        
        tableView.register(R.nib.peerCell)
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        
        initDataOperation.addExecutionBlock { [weak self] in
            let ids = AppGroupUserDefaults.User.recentlyUsedAppIds
            let recentAppUsers = UserDAO.shared.getUsers(ofAppIds: ids)
            let needsLoadAllUsers = DispatchQueue.main.sync {
                guard let self else {
                    return false
                }
                self.recentAppUsers = recentAppUsers
                self.tableView.reloadData()
                let needsLoadAllUsers = self.allAppUsers == nil
                if !needsLoadAllUsers {
                    self.searchBoxView.isBusy = false
                }
                return needsLoadAllUsers
            }
            if needsLoadAllUsers {
                let allUsers = UserDAO.shared.getAppUsers()
                DispatchQueue.main.sync {
                    guard let self else {
                        return
                    }
                    self.allAppUsers = allUsers
                    self.searchBoxView.isBusy = false
                }
            }
        }
        queue.maxConcurrentOperationCount = 1
        queue.addOperation(initDataOperation)
    }
    
    @IBAction func searchKeyword(_ sender: Any) {
        guard let keyword = trimmedLowercaseKeyword else {
            cancelSearchOperations()
            lastKeyword = nil
            searchBoxView.isBusy = false
            content = .recentApps
            tableView.reloadData()
            return
        }
        guard keyword != lastKeyword else {
            searchBoxView.isBusy = false
            return
        }
        cancelSearchOperations()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            let users = DispatchQueue.main.sync {
                self.allAppUsers ?? []
            }
            let searchResults = users.filter { user in
                user.matches(lowercasedKeyword: keyword)
            }.map { user in
                AppUserSearchResult(user: user, keyword: keyword)
            }
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                self.lastKeyword = keyword
                self.searchResults = searchResults
                self.content = .searchResult
                self.tableView.reloadData()
                self.searchBoxView.isBusy = false
            }
        }
        queue.addOperation(op)
        searchBoxView.isBusy = true
    }
    
    @IBAction func cancelSearching(_ sender: Any) {
        (parent as? ExploreViewController)?.cancelSearching()
    }
    
    private func cancelSearchOperations() {
        queue.operations
            .filter { $0 != initDataOperation }
            .forEach { $0.cancel() }
    }
    
}

extension ExploreSearchViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch content {
        case .recentApps:
            return recentAppUsers.count
        case .searchResult:
            return searchResults.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
        switch content {
        case .recentApps:
            let user = recentAppUsers[indexPath.row]
            cell.render(user: user)
        case .searchResult:
            let result = searchResults[indexPath.row]
            cell.render(result: result)
        }
        cell.peerInfoView.avatarImageView.hasShadow = false
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
}

extension ExploreSearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchBoxView.textField.resignFirstResponder()
        let item: UserItem
        switch content {
        case .recentApps:
            item = recentAppUsers[indexPath.row]
        case .searchResult:
            item = searchResults[indexPath.row].user
        }
        let profile = UserProfileViewController(user: item)
        present(profile, animated: true)
    }
    
}
