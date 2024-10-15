import UIKit
import Alamofire
import GRDB
import MixinServices

class SearchViewController: UIViewController, HomeSearchViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var recentAppsContainerView: UIView!
    
    let cancelButton = SearchCancelButton()
    
    var wantsNavigationSearchBox: Bool {
        return true
    }
    
    var navigationSearchBoxInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 20, bottom: 0, right: cancelButton.frame.width + cancelButtonRightMargin)
    }
    
    private let resultLimit = 3
    
    private var queue = OperationQueue()
    private var quickAccess: QuickAccessSearchResult?
    private var assets = [AssetSearchResult]()
    private var users = [SearchResult]()
    private var conversationsByName = [SearchResult]()
    private var conversationsByMessage = [SearchResult]()
    private var lastKeyword: String?
    private var recentAppsViewController: RecentAppsViewController?
    private var lastSearchFieldText: String?
    private var snapshot: DatabaseSnapshot?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let vc = segue.destination as? RecentAppsViewController {
            recentAppsViewController = vc
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        navigationItem.title = ""
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
        tableView.register(SearchHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(SearchFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.register(R.nib.peerCell)
        tableView.register(R.nib.assetCell)
        tableView.register(R.nib.quickAccessResultCell)
        let tableHeaderView = UIView()
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude)
        tableView.tableHeaderView = tableHeaderView
        tableView.dataSource = self
        tableView.delegate = self
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
        searchTextField.removeTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        lastSearchFieldText = searchTextField.text
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        [users, conversationsByName, conversationsByMessage]
            .flatMap({ $0 })
            .forEach({ $0.updateTitleAndDescription() })
        tableView.reloadData()
    }
    
    @IBAction func searchAction(_ sender: Any) {
        guard let keyword = trimmedKeyword else {
            showRecentApps()
            lastKeyword = nil
            cancelOperation()
            navigationSearchBoxView.isBusy = false
            return
        }
        cancelOperation()
        guard keyword != lastKeyword else {
            navigationSearchBoxView.isBusy = false
            return
        }
        quickAccess?.cancelPreviousPerformRequest()
        let limit = self.resultLimit + 1 // Query 1 more object to see if there's more objects than the limit
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            
            let quickAccess = QuickAccessSearchResult(keyword: keyword)
            let assets = TokenDAO.shared.search(keyword: keyword, sortResult: true, limit: limit)
                .map { AssetSearchResult(asset: $0, keyword: keyword) }
            guard !op.isCancelled else {
                return
            }

            let users = UserDAO.shared.getUsers(keyword: keyword, limit: limit)
                .map { UserSearchResult(user: $0, keyword: keyword) }
            guard !op.isCancelled else {
                return
            }

            let conversationsByName = ConversationDAO.shared.getGroupOrStrangerConversation(withNameLike: keyword, limit: limit)
                .map { ConversationSearchResult(conversation: $0, keyword: keyword) }
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                self.quickAccess = quickAccess
                self.assets = assets
                self.users = users
                self.conversationsByName = conversationsByName
                self.conversationsByMessage = []
                self.tableView.reloadData()
                self.showSearchResults()
                self.lastKeyword = keyword
            }
            
            let conversationsByMessage: [MessagesWithinConversationSearchResult]
            self.snapshot = try? UserDatabase.current.makeSnapshot()
            if let snapshot = self.snapshot {
                conversationsByMessage = ConversationDAO.shared.getConversation(from: snapshot, with: keyword, limit: limit)
            } else {
                conversationsByMessage = []
            }
            self.snapshot = nil
            
            guard !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                self.conversationsByMessage = conversationsByMessage
                UIView.performWithoutAnimation {
                    self.tableView.reloadSections(Section.conversation.indexSet, with: .none)
                }
                if !op.isCancelled {
                    self.navigationSearchBoxView.isBusy = false
                }
            }
        }
        queue.addOperation(op)
        navigationSearchBoxView.isBusy = true
    }
    
    func prepareForReuse() {
        cancelOperation()
        showRecentApps()
        assets = []
        users = []
        conversationsByName = []
        conversationsByMessage = []
        tableView.reloadData()
        lastKeyword = nil
        if let navigationController = navigationController as? SearchNavigationViewController {
            navigationController.viewControllers.removeAll(where: { $0 != self })
            navigationController.searchNavigationBar.layoutSearchBoxView(insets: navigationSearchBoxInsets)
        }
        lastSearchFieldText = nil
        searchTextField.text = nil
        navigationSearchBoxView.isBusy = false
    }
    
    func willHide() {
        quickAccess?.cancelPreviousPerformRequest()
    }
    
}

extension SearchViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .top:
            return quickAccess == nil ? 0 : 1
        case .asset:
            return min(resultLimit, assets.count)
        case .user:
            return min(resultLimit, users.count)
        case .group:
            return min(resultLimit, conversationsByName.count)
        case .conversation:
            return min(resultLimit, conversationsByMessage.count)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .top:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.quick_access, for: indexPath)!
            cell.result = quickAccess
            return cell
        case .asset:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
            let result = assets[indexPath.row]
            cell.render(asset: result.asset, attributedSymbol: result.attributedSymbol)
            return cell
        case .user:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            cell.render(result: users[indexPath.row])
            return cell
        case .group:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            cell.render(result: conversationsByName[indexPath.row])
            return cell
        case .conversation:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.peer, for: indexPath)!
            cell.render(result: conversationsByMessage[indexPath.row])
            return cell
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
}

extension SearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let section = Section(rawValue: indexPath.section)!
        switch section {
        case .top:
            return UITableView.automaticDimension
        case .asset, .user, .group, .conversation:
            return PeerCell.height
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = Section(rawValue: section)!
        switch section {
        case .top:
            return .leastNormalMagnitude
        case .asset, .user, .group, .conversation:
            if isEmptySection(section) {
                return .leastNormalMagnitude
            } else {
                return SearchHeaderView.height(isFirstSection: isFirstSection(section))
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let section = Section(rawValue: section)!
        switch section {
        case .top:
            return .leastNormalMagnitude
        case .asset, .user, .group, .conversation:
            return isEmptySection(section) ? .leastNormalMagnitude : SearchFooterView.height
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = Section(rawValue: section)!
        switch section {
        case .top:
            return nil
        case .asset, .user, .group, .conversation:
            if isEmptySection(section) {
                return nil
            } else {
                let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! SearchHeaderView
                view.isFirstSection = isFirstSection(section)
                view.label.text = section.title
                view.button.isHidden = models(forSection: section).count <= resultLimit
                view.section = section.rawValue
                view.delegate = self
                return view
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let section = Section(rawValue: section)!
        switch section {
        case .top:
            return nil
        case .asset, .user, .group, .conversation:
            if isEmptySection(section) {
                return nil
            } else {
                return tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchTextField.resignFirstResponder()
        switch Section(rawValue: indexPath.section)! {
        case .top:
            quickAccess?.performQuickAccess() { [weak self] item in
                guard let item else {
                    return
                }
                let profile = UserProfileViewController(user: item)
                self?.present(profile, animated: true)
            }
        case .asset:
            pushTokenViewController(token: assets[indexPath.row].asset)
        case .user:
            pushViewController(keyword: trimmedKeyword, result: users[indexPath.row])
        case .group:
            pushViewController(keyword: trimmedKeyword, result: conversationsByName[indexPath.row])
        case .conversation:
            pushViewController(keyword: trimmedKeyword, result: conversationsByMessage[indexPath.row])
        }
    }
    
}

extension SearchViewController: SearchHeaderViewDelegate {
    
    func searchHeaderViewDidSendMoreAction(_ view: SearchHeaderView) {
        guard let sectionValue = view.section, let section = Section(rawValue: sectionValue) else {
            return
        }
        let vc = R.storyboard.home.search_category()!
        switch section {
        case .top:
            return
        case .asset:
            vc.category = .asset
        case .user:
            vc.category = .user
        case .group:
            vc.category = .conversationsByName
        case .conversation:
            vc.category = .conversationsByMessage
        }
        searchTextField.resignFirstResponder()
        searchNavigationController?.pushViewController(vc, animated: true)
    }
    
}

extension SearchViewController {
    
    enum ReuseId {
        static let header = "header"
        static let footer = "footer"
    }
    
    enum Section: Int, CaseIterable {
        case top = 0
        case asset
        case user
        case group
        case conversation
        
        var title: String? {
            switch self {
            case .top:
                return nil
            case .asset:
                return R.string.localizable.assets()
            case .user:
                return R.string.localizable.contact_title()
            case .group:
                return R.string.localizable.conversations()
            case .conversation:
                return R.string.localizable.messages()
            }
        }
        
        var indexSet: IndexSet {
            return IndexSet(integer: rawValue)
        }
        
    }
    
    private func cancelOperation() {
        snapshot?.interrupt()
        snapshot = nil
        queue.cancelAllOperations()
    }
    
    private func showSearchResults() {
        tableView.isHidden = false
        recentAppsContainerView.isHidden = true
    }
    
    private func showRecentApps() {
        tableView.isHidden = true
        recentAppsViewController?.reloadIfNeeded()
        recentAppsContainerView.isHidden = false
    }
    
    private func models(forSection section: Section) -> [Any] {
        switch section {
        case .top:
            return []
        case .asset:
            return assets
        case .user:
            return users
        case .group:
            return conversationsByName
        case .conversation:
            return conversationsByMessage
        }
    }
    
    private func isEmptySection(_ section: Section) -> Bool {
        switch section {
        case .top:
            return quickAccess == nil
        case .asset, .user, .group, .conversation:
            return models(forSection: section).isEmpty
        }
    }
    
    private func isFirstSection(_ section: Section) -> Bool {
        let showTopResult = quickAccess != nil
        switch section {
        case .top:
            return showTopResult
        case .asset:
            return !showTopResult
        case .user:
            return !showTopResult && assets.isEmpty
        case .group:
            return !showTopResult && assets.isEmpty && users.isEmpty
        case .conversation:
            return !showTopResult && assets.isEmpty && users.isEmpty && conversationsByName.isEmpty
        }
    }
    
}
