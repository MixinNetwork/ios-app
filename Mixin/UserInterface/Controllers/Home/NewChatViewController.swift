import UIKit
import MixinServices

final class NewChatViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var tableView: UITableView!
    
    private let queue = OperationQueue()
    private let headerReuseID = "header"
    
    private weak var actionNavigationController: UINavigationController?
    
    private var sectionTitles: [String] = []
    private var contacts: [[UserItem]] = []
    private var searchResults: [UserSearchResult] = []
    private var searchingKeyword: String?
    private var searchOperation: BlockOperation?
    
    init(actionNavigationController: UINavigationController?) {
        self.actionNavigationController = actionNavigationController
        let nib = R.nib.newChatView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        queue.cancelAllOperations()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.new_chat()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close(_:)),
        )
        tableView.rowHeight = PeerCell.height
        tableView.sectionIndexColor = R.color.text_tertiary()
        tableView.register(PeerCell.nib, forCellReuseIdentifier: PeerCell.reuseIdentifier)
        tableView.register(R.nib.newChatActionCell)
        tableView.register(PeerHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseID)
        tableView.dataSource = self
        tableView.delegate = self
        searchBoxView.textField.placeholder = R.string.localizable.setting_auth_search_hint()
        searchBoxView.textField.addTarget(
            self,
            action: #selector(textFieldEditingChanged(_:)),
            for: .editingChanged,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(usersDidChange),
            name: UserDAO.usersDidChangeNotification,
            object: nil,
        )
        queue.maxConcurrentOperationCount = 1
        reloadContacts()
        ContactAPI.syncContacts()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory else {
            return
        }
        for result in searchResults {
            result.updateTitleAndDescription()
        }
        if searchingKeyword != nil {
            tableView.reloadData()
        }
    }
    
    @objc private func textFieldEditingChanged(_ textField: UITextField) {
        let keyword = (textField.text ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard keyword != searchingKeyword else {
            return
        }
        searchOperation?.cancel()
        searchResults = []
        searchingKeyword = keyword.isEmpty ? nil : keyword
        tableView.reloadData()
        if !keyword.isEmpty {
            search(keyword: keyword)
        }
    }
    
    @objc private func usersDidChange() {
        reloadContacts()
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    private func reloadContacts() {
        class ObjcAccessibleUser: NSObject {
            
            @objc let fullName: String
            let user: UserItem
            
            init(user: UserItem) {
                self.fullName = user.fullName
                self.user = user
                super.init()
            }
            
        }
        
        queue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [unowned operation, weak self] in
            guard self != nil, !operation.isCancelled else {
                return
            }
            let objcAccessibleUsers = UserDAO.shared
                .contactsWithoutApp(limit: nil)
                .map(ObjcAccessibleUser.init)
            let (titles, objcUsers) = UILocalizedIndexedCollation.current()
                .catalog(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessibleUser.fullName))
            let contacts = objcUsers.map { $0.map(\.user) }
            DispatchQueue.main.sync {
                guard let self, !operation.isCancelled else {
                    return
                }
                self.sectionTitles = titles
                self.contacts = contacts
                if let keyword = self.searchingKeyword {
                    self.searchResults = []
                    self.search(keyword: keyword)
                }
                self.tableView.reloadData()
            }
        }
        queue.addOperation(operation)
    }
    
    private func search(keyword: String) {
        searchOperation?.cancel()
        let operation = BlockOperation()
        let contacts = contacts
        operation.addExecutionBlock { [unowned operation, weak self] in
            guard self != nil, !operation.isCancelled else {
                return
            }
            let results = contacts.flatMap { $0 }
                .filter { $0.matches(lowercasedKeyword: keyword) }
                .map { UserSearchResult(user: $0, keyword: keyword) }
            DispatchQueue.main.sync {
                guard let self,
                      !operation.isCancelled,
                      self.searchingKeyword == keyword
                else {
                    return
                }
                self.searchResults = results
                self.tableView.reloadData()
            }
        }
        searchOperation = operation
        queue.addOperation(operation)
    }
    
}

extension NewChatViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        searchingKeyword == nil ? contacts.count + 1 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchingKeyword != nil {
            searchResults.count
        } else if section == 0 {
            2
        } else {
            contacts[section - 1].count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if searchingKeyword == nil, indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.new_chat_action, for: indexPath)!
            switch indexPath.row {
            case 0:
                cell.iconImageView.image = R.image.new_group()
                cell.titleLabel.text = R.string.localizable.new_group()
            default:
                cell.iconImageView.image = R.image.ic_user_add_contact()
                cell.titleLabel.text = R.string.localizable.add_contact()
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: PeerCell.reuseIdentifier, for: indexPath) as! PeerCell
            if searchingKeyword != nil {
                cell.render(result: searchResults[indexPath.row])
            } else {
                cell.render(user: contacts[indexPath.section - 1][indexPath.row])
            }
            cell.peerInfoViewLeadingConstraint?.constant = 16
            cell.peerInfoViewTrailingConstraint?.constant = 16
            return cell
        }
    }
    
    func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        searchingKeyword == nil ? sectionTitles : nil
    }
    
    func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        index + 1
    }
    
}

extension NewChatViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard searchingKeyword == nil, section > 0, !contacts[section - 1].isEmpty else {
            return .leastNormalMagnitude
        }
        return 36
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard searchingKeyword == nil, section > 0, !contacts[section - 1].isEmpty else {
            return nil
        }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseID) as! PeerHeaderView
        header.label.text = sectionTitles[section - 1]
        return header
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        searchBoxView.textField.resignFirstResponder()
        guard let presentingViewController else {
            return
        }
        let action: UIViewController
        if searchingKeyword == nil, indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                action = AddMemberViewController.instance(appendingMembersToConversationId: nil)
            default:
                action = AddContactViewController()
            }
        } else {
            let user: UserItem
            if searchingKeyword != nil {
                user = searchResults[indexPath.row].user
            } else {
                user = contacts[indexPath.section - 1][indexPath.row]
            }
            action = ConversationViewController.instance(ownerUser: user)
        }
        presentingViewController.dismiss(animated: true) { [weak actionNavigationController] in
            actionNavigationController?.pushViewController(action, animated: true)
        }
    }
    
}
