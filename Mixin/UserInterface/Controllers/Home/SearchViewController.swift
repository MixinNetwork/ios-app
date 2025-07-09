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
    private var maoUser: MAONameSearchResult?
    private var assets = [AssetSearchResult]()
    private var users = [SearchResult]()
    private var conversationsByName = [SearchResult]()
    private var conversationsByMessage = [SearchResult]()
    private var lastKeyword: String?
    private var recentAppsViewController: RecentAppsViewController?
    private var lastSearchFieldText: String?
    private var snapshot: DatabaseSnapshot?
    
    private weak var maoNameSearchRequest: Request?
    
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
        tableView.register(R.nib.maoNameSearchResultCell)
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
            cancelOperation()
            maoNameSearchRequest?.cancel()
            showRecentApps()
            lastKeyword = nil
            navigationSearchBoxView.isBusy = false
            return
        }
        guard keyword != lastKeyword else {
            navigationSearchBoxView.isBusy = false
            return
        }
        cancelOperation()
        quickAccess?.cancelPreviousPerformRequest()
        maoNameSearchRequest?.cancel()
        let limit = self.resultLimit + 1 // Query 1 more object to see if there's more objects than the limit
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            Thread.sleep(forTimeInterval: 0.5)
            guard !op.isCancelled else {
                return
            }
            
            let quickAccess = QuickAccessSearchResult(keyword: keyword)
            let assets = TokenDAO.shared.search(
                keyword: keyword,
                includesZeroBalanceItems: false,
                sorting: true,
                limit: limit
            ).map { token in
                AssetSearchResult(asset: token, keyword: keyword)
            }
            guard !op.isCancelled else {
                return
            }
            
            switch quickAccess?.content {
            case .number:
                break
            case .link, .none:
                let name = if keyword.hasSuffix(".mao") {
                    String(keyword[keyword.startIndex..<keyword.index(keyword.endIndex, offsetBy: -4)])
                } else {
                    keyword
                }
                let range = NSRange(name.startIndex..<name.endIndex, in: name)
                if let regex = try? NSRegularExpression(pattern: #"^[^\sA-Z]{1,128}$"#),
                   regex.firstMatch(in: name, range: range) != nil,
                   let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                   !op.isCancelled
                {
                    DispatchQueue.main.sync {
                        self.maoNameSearchRequest = UserAPI.search(keyword: encodedKeyword) { [weak self] result in
                            switch result {
                            case .failure(let error):
                                Logger.general.debug(category: "Search", message: "\(error)")
                            case .success(let response):
                                guard let self, self.trimmedKeyword == keyword else {
                                    return
                                }
                                self.maoUser = MAONameSearchResult(keyword: keyword, name: name, response: response)
                                var sections = IndexSet(integer: Section.maoUser.rawValue)
                                let firstNotEmptySectionAfterMAOUser = Section.allCases.filter { section in
                                    section.rawValue > Section.maoUser.rawValue
                                }.first { section in
                                    !self.isEmptySection(section)
                                }
                                if let section = firstNotEmptySectionAfterMAOUser {
                                    // Update the header
                                    sections.insert(section.rawValue)
                                }
                                UIView.performWithoutAnimation {
                                    self.tableView.reloadSections(sections, with: .none)
                                }
                            }
                        }
                    }
                }
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
                if self.maoUser?.keyword != keyword {
                    self.maoUser = nil
                }
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
        quickAccess = nil
        maoUser = nil
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
        case .quickAccess:
            quickAccess == nil ? 0 : 1
        case .maoUser:
            maoUser == nil ? 0 : 1
        case .asset:
            min(resultLimit, assets.count)
        case .user:
            min(resultLimit, users.count)
        case .group:
            min(resultLimit, conversationsByName.count)
        case .conversation:
            min(resultLimit, conversationsByMessage.count)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .quickAccess:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.quick_access, for: indexPath)!
            cell.result = quickAccess
            return cell
        case .maoUser:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.mao_name_search_result, for: indexPath)!
            if let result = maoUser {
                cell.load(result: result)
            }
            return cell
        case .asset:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
            let result = assets[indexPath.row]
            cell.render(token: result.asset, attributedSymbol: result.attributedSymbol)
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
        Section.allCases.count
    }
    
}

extension SearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .quickAccess:
            UITableView.automaticDimension
        case .maoUser:
            MAONameSearchResultCell.height
        case .asset, .user, .group, .conversation:
            PeerCell.height
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = Section(rawValue: section)!
        switch section {
        case .quickAccess, .maoUser:
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
        case .quickAccess, .maoUser:
            return .leastNormalMagnitude
        case .asset, .user, .group, .conversation:
            return isEmptySection(section) ? .leastNormalMagnitude : SearchFooterView.height
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = Section(rawValue: section)!
        switch section {
        case .quickAccess, .maoUser:
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
        case .quickAccess, .maoUser:
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
        case .quickAccess:
            quickAccess?.performQuickAccess() { [weak self] item in
                guard let item else {
                    return
                }
                let profile = UserProfileViewController(user: item)
                self?.present(profile, animated: true)
            }
        case .maoUser:
            if let app = maoUser?.app, let home = UIApplication.homeContainerViewController?.homeTabBarController {
                let webView = MixinWebViewController.instance(with: .init(conversationId: "", app: app))
                webView.presentAsChild(of: home, completion: nil)
            } else if let user = maoUser?.user, user.isCreatedByMessenger {
                let vc = ConversationViewController.instance(ownerUser: user)
                homeNavigationController?.pushViewController(vc, animated: true)
            }
        case .asset:
            pushTokenViewController(token: assets[indexPath.row].asset, source: "chat_search")
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
        case .quickAccess, .maoUser:
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
    
    private enum ReuseId {
        static let header = "h"
        static let footer = "f"
    }
    
    private enum Section: Int, CaseIterable {
        
        case quickAccess = 0
        case maoUser
        case asset
        case user
        case group
        case conversation
        
        var title: String? {
            switch self {
            case .quickAccess, .maoUser:
                nil
            case .asset:
                R.string.localizable.assets()
            case .user:
                R.string.localizable.contact_title()
            case .group:
                R.string.localizable.conversations()
            case .conversation:
                R.string.localizable.messages()
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
        case .quickAccess, .maoUser:
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
        case .quickAccess:
            quickAccess == nil
        case .maoUser:
            maoUser == nil
        case .asset, .user, .group, .conversation:
            models(forSection: section).isEmpty
        }
    }
    
    private func isFirstSection(_ section: Section) -> Bool {
        return switch section {
        case .quickAccess:
            quickAccess != nil
        case .maoUser:
            quickAccess == nil && maoUser != nil
        case .asset:
            quickAccess == nil && maoUser == nil
        case .user:
            quickAccess == nil && maoUser == nil && assets.isEmpty
        case .group:
            quickAccess == nil && maoUser == nil && assets.isEmpty && users.isEmpty
        case .conversation:
            quickAccess == nil && maoUser == nil && assets.isEmpty && users.isEmpty && conversationsByName.isEmpty
        }
    }
    
}
