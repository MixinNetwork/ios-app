import UIKit

class SearchViewController: UIViewController, SearchableViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var recentBotsContainerView: UIView!
    
    let titleView = R.nib.searchTitleView(owner: nil)!
    
    var searchTextField: UITextField {
        return titleView.searchBoxView.textField
    }
    
    private let searchingFooterView = R.nib.searchingFooterView(owner: nil)
    private let resultLimit = 3
    
    private var queue = OperationQueue()
    private var assets = [AssetSearchResult]()
    private var users = [SearchResult]()
    private var groups = [SearchResult]()
    private var conversations = [SearchResult]()
    
    private var keywordMaybeIdOrPhone: Bool {
        return searchTextField.text?.isNumeric ?? false
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.maxConcurrentOperationCount = 1
        navigationItem.title = " "
        navigationItem.titleView = titleView
        tableView.register(SearchHeaderView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(SearchFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.register(R.nib.searchResultCell)
        tableView.register(R.nib.assetCell)
        let tableHeaderView = UIView()
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude)
        tableView.tableHeaderView = tableHeaderView
        tableView.dataSource = self
        tableView.delegate = self
        searchTextField.addTarget(self, action: #selector(searchAction(_:)), for: .editingChanged)
        NotificationCenter.default.addObserver(self, selector: #selector(contactsDidChange(_:)), name: .ContactsDidChange, object: nil)
    }
    
    @IBAction func searchAction(_ sender: Any) {
        let keyword = self.trimmedLowercaseKeyword
        guard !keyword.isEmpty else {
            tableView.isHidden = true
            recentBotsContainerView.isHidden = false
            return
        }
        tableView.isHidden = false
        recentBotsContainerView.isHidden = true
        let limit = self.resultLimit + 1 // Query 1 more object to see if there's more objects than the limit
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let assets = AssetDAO.shared.getAssets(keyword: keyword, limit: limit)
                .map { AssetSearchResult(asset: $0, keyword: keyword) }
            let contacts = UserDAO.shared.getUsers(keyword: keyword, limit: limit)
                .map { SearchResult(user: $0, keyword: keyword) }
            let groups = ConversationDAO.shared.getGroupConversation(nameLike: keyword, limit: limit)
                .map { SearchResult(group: $0, keyword: keyword) }
            let conversations = ConversationDAO.shared.getConversation(withMessageLike: keyword, limit: limit)
            guard let weakSelf = self, !op.isCancelled else {
                return
            }
            DispatchQueue.main.sync {
                weakSelf.assets = assets
                weakSelf.users = contacts
                weakSelf.groups = groups
                weakSelf.conversations = conversations
                weakSelf.tableView.reloadData()
            }
        }
        queue.addOperation(op)
    }
    
    func prepareForReuse() {
        searchTextField.text = nil
        tableView.isHidden = true
        recentBotsContainerView.isHidden = false
        assets = []
        users = []
        groups = []
        conversations = []
        tableView.reloadData()
    }
    
    @objc func contactsDidChange(_ notification: Notification) {
        
    }
    
}

extension SearchViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .searchNumber:
            return keywordMaybeIdOrPhone ? 1 : 0
        case .asset:
            return min(resultLimit, assets.count)
        case .user:
            return min(resultLimit, users.count)
        case .group:
            return min(resultLimit, groups.count)
        case .conversation:
            return min(resultLimit, conversations.count)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .searchNumber:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.search_number, for: indexPath)!
            if let keyword = searchTextField.text {
                cell.render(number: keyword)
            }
            return cell
        case .asset:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
            let result = assets[indexPath.row]
            cell.render(asset: result.asset, attributedSymbol: result.attributedSymbol)
            return cell
        case .user:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.search_result, for: indexPath)!
            cell.render(result: users[indexPath.row])
            return cell
        case .group:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.search_result, for: indexPath)!
            cell.render(result: groups[indexPath.row])
            return cell
        case .conversation:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.search_result, for: indexPath)!
            cell.render(result: conversations[indexPath.row])
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
        case .searchNumber:
            return UITableView.automaticDimension
        case .asset, .user, .group, .conversation:
            return SearchResultCell.height
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = Section(rawValue: section)!
        switch section {
        case .searchNumber:
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
        case .searchNumber:
            return .leastNormalMagnitude
        case .asset, .user, .group, .conversation:
            return isEmptySection(section) ? .leastNormalMagnitude : SearchFooterView.height
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let section = Section(rawValue: section)!
        switch section {
        case .searchNumber:
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
        case .searchNumber:
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
        case .searchNumber:
            break
        case .asset:
            pushAssetViewController(asset: assets[indexPath.row].asset)
        case .user:
            pushViewController(keyword: trimmedLowercaseKeyword, result: users[indexPath.row])
        case .group:
            pushViewController(keyword: trimmedLowercaseKeyword, result: groups[indexPath.row])
        case .conversation:
            pushViewController(keyword: trimmedLowercaseKeyword, result: conversations[indexPath.row])
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
        case .searchNumber:
            return
        case .asset:
            vc.category = .asset
        case .user:
            vc.category = .contact
        case .group:
            vc.category = .group
        case .conversation:
            vc.category = .conversation
        }
        vc.inheritedKeyword = trimmedLowercaseKeyword
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
        case searchNumber = 0
        case asset
        case user
        case group
        case conversation
        
        var title: String? {
            switch self {
            case .searchNumber:
                return nil
            case .asset:
                return R.string.localizable.search_section_title_asset()
            case .user:
                return R.string.localizable.search_section_title_user()
            case .group:
                return R.string.localizable.search_section_title_group()
            case .conversation:
                return R.string.localizable.search_section_title_conversation()
            }
        }
    }
    
    private func models(forSection section: Section) -> [Any] {
        switch section {
        case .searchNumber:
            return []
        case .asset:
            return assets
        case .user:
            return users
        case .group:
            return groups
        case .conversation:
            return conversations
        }
    }
    
    private func isEmptySection(_ section: Section) -> Bool {
        switch section {
        case .searchNumber:
            return !keywordMaybeIdOrPhone
        case .asset, .user, .group, .conversation:
            return models(forSection: section).isEmpty
        }
    }
    
    private func isFirstSection(_ section: Section) -> Bool {
        switch section {
        case .searchNumber:
            return keywordMaybeIdOrPhone
        case .asset:
            return !keywordMaybeIdOrPhone
        case .user:
            return !keywordMaybeIdOrPhone && assets.isEmpty
        case .group:
            return !keywordMaybeIdOrPhone && assets.isEmpty && users.isEmpty
        case .conversation:
            return !keywordMaybeIdOrPhone && assets.isEmpty && users.isEmpty && groups.isEmpty
        }
    }
    
}
