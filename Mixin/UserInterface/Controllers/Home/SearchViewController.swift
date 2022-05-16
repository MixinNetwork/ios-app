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
    private let idOrPhoneCharacterSet = Set("+0123456789")
    private let phoneNumberValidator = PhoneNumberValidator()
    
    private var queue = OperationQueue()
    private var topResult: TopResult?
    private var assets = [AssetSearchResult]()
    private var users = [SearchResult]()
    private var conversationsByName = [SearchResult]()
    private var conversationsByMessage = [SearchResult]()
    private var lastKeyword: String?
    private var recentAppsViewController: RecentAppsViewController?
    private var searchNumberRequest: Request?
    private var lastSearchFieldText: String?
    private var snapshot: DatabaseSnapshot?
    
    private var topResultCell: TopResultCell? {
        let indexPath = IndexPath(row: 0, section: Section.top.rawValue)
        return tableView.cellForRow(at: indexPath) as? TopResultCell
    }
    
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
        navigationItem.title = " "
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: cancelButton)
        tableView.register(SearchHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(SearchFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.register(R.nib.peerCell)
        tableView.register(R.nib.assetCell)
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
        guard let keyword = trimmedLowercaseKeyword else {
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
        searchNumberRequest?.cancel()
        searchNumberRequest = nil
        let limit = self.resultLimit + 1 // Query 1 more object to see if there's more objects than the limit
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            
            let topResult = self.topResult(keyword: keyword)
            let assets = AssetDAO.shared.getAssets(keyword: keyword, sortResult: true, limit: limit)
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
                self.topResult = topResult
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
        searchNumberRequest?.cancel()
        searchNumberRequest = nil
    }
    
}

extension SearchViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .top:
            return topResult == nil ? 0 : 1
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
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.search_number, for: indexPath)!
            switch topResult {
            case let .number(number):
                cell.setText(number: number)
            case let .url(url):
                cell.setText(url: url)
            case .none:
                assertionFailure()
            }
            cell.isBusy = searchNumberRequest != nil
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
            switch topResult {
            case let .number(number):
                search(number: number)
            case let .url(url):
                if let parent = homeViewController {
                    MixinWebViewController.presentInstance(with: .init(conversationId: "", initialUrl: url), asChildOf: parent)
                }
            case .none:
                break
            }
        case .asset:
            pushAssetViewController(asset: assets[indexPath.row].asset)
        case .user:
            pushViewController(keyword: trimmedLowercaseKeyword, result: users[indexPath.row])
        case .group:
            pushViewController(keyword: trimmedLowercaseKeyword, result: conversationsByName[indexPath.row])
        case .conversation:
            pushViewController(keyword: trimmedLowercaseKeyword, result: conversationsByMessage[indexPath.row])
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
    
    enum TopResult {
        case number(String)
        case url(URL)
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
                return R.string.localizable.search_section_title_asset()
            case .user:
                return R.string.localizable.search_section_title_user()
            case .group:
                return R.string.localizable.search_section_title_conversation_by_name()
            case .conversation:
                return R.string.localizable.search_section_title_conversation_by_message()
            }
        }
        
        var indexSet: IndexSet {
            return IndexSet(integer: rawValue)
        }
        
    }
    
    private func topResult(keyword: String) -> TopResult? {
        let number: String? = {
            guard keyword.count >= 4 else {
                return nil
            }
            guard idOrPhoneCharacterSet.isSuperset(of: keyword) else {
                return nil
            }
            if keyword.contains("+") {
                if phoneNumberValidator.isValid(keyword) {
                    return keyword
                } else {
                    return nil
                }
            } else {
                return keyword
            }
        }()
        let url: URL? = {
            var url: URL?
            Link.detector.enumerateMatches(in: keyword, options: []) { match, _, stop in
                guard let match = match else {
                    return
                }
                let string = (keyword as NSString).substring(with: match.range)
                url = URL(string: string)
                stop.pointee = ObjCBool(url != nil)
            }
            return url
        }()
        
        if keyword.isEmpty {
            return nil
        } else if let number = number {
            return .number(number)
        } else if let url = url {
            return .url(url)
        } else {
            return nil
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
            return topResult == nil
        case .asset, .user, .group, .conversation:
            return models(forSection: section).isEmpty
        }
    }
    
    private func isFirstSection(_ section: Section) -> Bool {
        let showTopResult = topResult != nil
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
    
    private func search(number: String) {
        searchNumberRequest?.cancel()
        topResultCell?.isBusy = true
        searchNumberRequest = UserAPI.search(keyword: number) { [weak self] (result) in
            guard let weakSelf = self, weakSelf.searchNumberRequest != nil else {
                return
            }
            weakSelf.topResultCell?.isBusy = false
            weakSelf.searchNumberRequest = nil
            switch result {
            case let .success(user):
                UserDAO.shared.updateUsers(users: [user])
                let userItem = UserItem.createUser(from: user)
                if userItem.isCreatedByMessenger {
                    let vc = UserProfileViewController(user: userItem)
                    vc.updateUserFromRemoteAfterReloaded = false
                    weakSelf.present(vc, animated: true, completion: nil)
                }
            case let .failure(error):
                let text = error.localizedDescription(overridingNotFoundDescriptionWith: R.string.localizable.user_not_found())
                showAutoHiddenHud(style: .error, text: text)
            }
        }
    }
    
}
