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
    
    private var quickAccess: QuickAccessSearchResult?
    private var allAppUsers: [User]? = nil
    private var recentAppUsers: [UserItem] = []
    private var searchResults: [AppUserSearchResult] = []
    private var content: Content = .recentApps
    private var lastKeyword: String?
    
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
        tableView.register(R.nib.quickAccessResultCell)
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
        guard let keyword = searchBoxView.spacesTrimmedText?.lowercased() else {
            cancelSearchOperations()
            quickAccess = nil
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
        quickAccess?.cancelPreviousPerformRequest()
        cancelSearchOperations()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            let quickAccess = QuickAccessSearchResult(keyword: keyword)
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
                self.quickAccess = quickAccess
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
        searchBoxView.textField.resignFirstResponder()
        (parent as? ExploreViewController)?.dismissSearch()
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
            recentAppUsers.count
        case .searchResult:
            if section == 0 && quickAccess != nil {
                1
            } else {
                searchResults.count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch content {
        case .recentApps:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            let user = recentAppUsers[indexPath.row]
            cell.render(user: user)
            cell.peerInfoView.avatarImageView.hasShadow = false
            return cell
        case .searchResult:
            if let quickAccess, indexPath.section == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.quick_access, for: indexPath)!
                cell.result = quickAccess
                cell.topShadowView.backgroundColor = R.color.background_secondary()
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
                let result = searchResults[indexPath.row]
                cell.render(result: result)
                cell.peerInfoView.avatarImageView.hasShadow = false
                return cell
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        switch content {
        case .recentApps:
            1
        case .searchResult:
            quickAccess == nil ? 1 : 2
        }
    }
    
}

extension ExploreSearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if quickAccess != nil, indexPath.section == 0 {
            UITableView.automaticDimension
        } else {
            tableView.rowHeight
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchBoxView.textField.resignFirstResponder()
        switch content {
        case .recentApps:
            let item = recentAppUsers[indexPath.row]
            let profile = UserProfileViewController(user: item)
            present(profile, animated: true)
        case .searchResult:
            if let quickAccess, indexPath.section == 0 {
                quickAccess.performQuickAccess { [weak self] (item) in
                    if let item {
                        let profile = UserProfileViewController(user: item)
                        self?.present(profile, animated: true)
                    }
                }
            } else {
                let user = searchResults[indexPath.row].user
                let item = UserItem.createUser(from: user)
                let profile = UserProfileViewController(user: item)
                present(profile, animated: true)
            }
        }
    }
    
}
