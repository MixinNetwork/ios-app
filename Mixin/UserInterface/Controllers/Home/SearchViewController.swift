import UIKit

class SearchViewController: UIViewController {

    enum ReuseId {
        static let header = "header"
        static let contact = "contact"
        static let conversation = "conversation"
        static let asset = "asset"
        static let footer = "footer"
    }
    
    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    private let searchImageView = UIImageView(image: #imageLiteral(resourceName: "ic_search"))
    private let headerHeight: CGFloat = 41
    
    private var allContacts = [UserItem]()
    private var users = [UserItem]()
    private var assets = [AssetItem]()
    private var conversations = [ConversationItem]()
    private var searchQueue = OperationQueue()
    private var contactsLoadingQueue = OperationQueue()
    private var isPresenting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchQueue.maxConcurrentOperationCount = 1
        contactsLoadingQueue.maxConcurrentOperationCount = 1
        tableView.register(GeneralTableViewHeader.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(UINib(nibName: "SearchResultContactCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.contact)
        tableView.register(UINib(nibName: "ConversationCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.conversation)
        tableView.register(UINib(nibName: "AssetCell", bundle: .main),
                           forCellReuseIdentifier: ReuseId.asset)
        tableView.register(SearchFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        let tableHeaderView = UIView()
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude)
        tableView.tableHeaderView = tableHeaderView
        tableView.tableFooterView = UIView()
//        tableView.dataSource = self
//        tableView.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(contactsDidChange(_:)), name: .ContactsDidChange, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func searchAction(_ sender: Any) {
        let keyword = self.keyword
        searchQueue.cancelAllOperations()
        if keyword.isEmpty {
            self.assets = []
            self.users = []
            self.conversations = []
            showContacts()
        } else {
            tableView.reloadData()
            let op = BlockOperation()
            op.addExecutionBlock { [unowned op] in
                guard !op.isCancelled else {
                    return
                }
                let assets = AssetDAO.shared.searchAssets(content: keyword)
                let users = UserDAO.shared.getUsers(nameOrPhone: keyword)
                let messages = ConversationDAO.shared.searchConversation(content: keyword)
                DispatchQueue.main.sync {
                    guard !op.isCancelled else {
                        return
                    }
                    self.assets = assets
                    self.users = users
                    self.conversations = messages
                    self.tableView.reloadData()
                    self.updateNoResultIndicator()
                }
            }
            searchQueue.addOperation(op)
        }
    }

    func prepare() {
        reloadContacts()
    }
    
    @objc func contactsDidChange(_ notification: Notification) {
        reloadContacts()
    }
    
    class func instance() -> SearchViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "search") as! SearchViewController
    }
    
    private var keyword: String {
        return keywordTextField.text ?? ""
    }
    
    private func reloadContacts() {
        contactsLoadingQueue.cancelAllOperations()
        contactsLoadingQueue.addOperation {
            let allContacts = UserDAO.shared.contacts()
            DispatchQueue.main.async {
                self.allContacts = allContacts
                if self.isPresenting && self.keyword.isEmpty {
                    self.tableView.reloadData()
                    self.updateNoResultIndicator()
                }
            }
        }
    }
    
    private func showContacts() {
        if allContacts.isEmpty {
            reloadContacts()
        } else {
            tableView.reloadData()
            updateNoResultIndicator()
        }
    }
    
    private func updateNoResultIndicator() {
        let dataCount: Int
        if keyword.isEmpty {
            dataCount = allContacts.count
            tableView.subviews.forEach {
                ($0 as? EmptyView)?.removeFromSuperview()
            }
        } else {
            dataCount = assets.count + users.count + conversations.count
            tableView.checkEmpty(dataCount: dataCount,
                                 text: Localized.NO_RESULT,
                                 photo: R.image.ic_no_result()!)
        }
    }
    
}

extension SearchViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if keyword.isEmpty {
            return 1
        } else {
            return (assets.isEmpty ? 0 : 1) + (users.isEmpty ? 0 : 1) + (conversations.isEmpty ? 0 : 1)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if keyword.isEmpty {
            return allContacts.count
        } else {
            if assets.count > 0 && section == 0 {
                return assets.count
            } else if users.count > 0 && (section == 0 || (assets.count > 0 && section == 1)) {
                return users.count
            } else {
                return conversations.count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if keyword.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.contact, for: indexPath) as! SearchResultContactCell
            cell.render(user: allContacts[indexPath.row])
            return cell
        } else {
            let section = indexPath.section
            if section == 0 && assets.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.asset, for: indexPath) as! AssetCell
                cell.render(asset: assets[indexPath.row])
                return cell
            } else if users.count > 0 && (section == 0 || (assets.count > 0 && section == 1)) {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.contact, for: indexPath) as! SearchResultContactCell
                cell.render(user: users[indexPath.row])
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.conversation, for: indexPath) as! ConversationCell
                cell.render(item: conversations[indexPath.row])
                return cell
            }
        }
    }
}

extension SearchViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if keyword.isEmpty {
            return SearchResultContactCell.height
        } else {
            let section = indexPath.section
            if section == 0 && assets.count > 0 {
                return AssetCell.height
            } else if users.count > 0 && (section == 0 || (assets.count > 0 && section == 1)) {
                return SearchResultContactCell.height
            } else {
                return ConversationCell.height
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if keyword.isEmpty {
            if allContacts.isEmpty {
                return .leastNormalMagnitude
            } else {
                return headerHeight
            }
        } else {
            return assets.count > 0 || users.count > 0 || conversations.count > 0 ? headerHeight : .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! GeneralTableViewHeader
        if keyword.isEmpty {
            if allContacts.isEmpty {
                return nil
            } else {
                header.label.text = Localized.SECTION_TITLE_CONTACTS
            }
        } else {
            if assets.count > 0 && section == 0 {
                header.label.text = Localized.SECTION_TITLE_ASSETS
            } else if users.count > 0 && (section == 0 || (assets.count > 0 && section == 1)) {
                header.label.text = Localized.SECTION_TITLE_CONTACTS
            } else {
                header.label.text = Localized.SECTION_TITLE_MESSAGES
            }
        }
        return header
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        var shouldShowFooter = false
        for section in 0..<numberOfSections(in: tableView) {
            if self.tableView(tableView, numberOfRowsInSection: section) > 0 {
                shouldShowFooter = true
                break
            }
        }
        if shouldShowFooter {
            let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer) as! SearchFooterView
            footer.shadowView.hasLowerShadow = section != numberOfSections(in: tableView) - 1
            return footer
        } else {
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if keyword.isEmpty {
            navigationController?.pushViewController(ConversationViewController.instance(ownerUser: allContacts[indexPath.row]), animated: true)
        } else {
            let section = indexPath.section
            if assets.count > 0 && section == 0 {
                navigationController?.pushViewController(AssetViewController.instance(asset: assets[indexPath.row]), animated: true)
            } else if users.count > 0 && (section == 0 || (assets.count > 0 && section == 1)) {
                navigationController?.pushViewController(ConversationViewController.instance(ownerUser: users[indexPath.row]), animated: true)
            } else {
                let conversation = conversations[indexPath.row]
                let highlight = ConversationDataSource.Highlight(keyword: keyword, messageId: conversation.messageId)
                let vc = ConversationViewController.instance(conversation: conversation, highlight: highlight)
                navigationController?.pushViewController(vc, animated: true)
            }
        }
    }
    
}
