import UIKit
import MixinServices

class ContactViewController: PeerViewController<[UserItem], PeerCell, UserSearchResult> {
    
    private var showAddContactButton = true
    
    class func instance(showAddContactButton: Bool = true) -> UIViewController {
        let controller = ContactViewController()
        controller.showAddContactButton = showAddContactButton
        let title = showAddContactButton ? R.string.localizable.contacts() : R.string.localizable.new_chat()
        return ContainerViewController.instance(viewController: controller, title: title)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.setting_auth_search_hint()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(contactsDidChange),
                                               name: UserDAO.contactsDidChangeNotification,
                                               object: nil)
        ContactAPI.syncContacts()
    }
    
    override func initData() {
        reloadContacts(operation: initDataOperation)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let users = models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let searchResult = users.flatMap({ $0 })
                .filter({ $0.matches(lowercasedKeyword: keyword) })
                .map({ UserSearchResult(user: $0, keyword: keyword) })
            DispatchQueue.main.sync {
                guard let self = self, !op.isCancelled else {
                    return
                }
                self.searchingKeyword = keyword
                self.searchResults = searchResult
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
        queue.addOperation(op)
    }
    
    override func configure(cell: PeerCell, at indexPath: IndexPath) {
        super.configure(cell: cell, at: indexPath)
        if isSearching {
            cell.render(result: searchResults[indexPath.row])
        } else {
            let user = models[indexPath.section][indexPath.row]
            cell.render(user: user)
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isSearching ? searchResults.count : models[section].count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        isSearching ? 1 : sectionTitles.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user: UserItem
        if isSearching {
            user = searchResults[indexPath.row].user
        } else {
            user = models[indexPath.section][indexPath.row]
        }
        let vc = ConversationViewController.instance(ownerUser: user)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func contactsDidChange() {
        if isSearching {
            queue.cancelAllOperations()
            searchResults = []
            tableView.reloadData()
        }
        reloadContacts(operation: BlockOperation())
    }
    
    private func reloadContacts(operation: BlockOperation) {
        class ObjcAccessibleUser: NSObject {
            @objc let fullName: String
            let user: UserItem
            init(user: UserItem) {
                self.fullName = user.fullName
                self.user = user
                super.init()
            }
        }
        operation.addExecutionBlock { [weak self] in
            let objcAccessibleUsers = UserDAO.shared.contactsWithoutApp()
                .map(ObjcAccessibleUser.init)
            let (titles, objcUsers) = UILocalizedIndexedCollation.current()
                .catalogue(objcAccessibleUsers, usingSelector: #selector(getter: ObjcAccessibleUser.fullName))
            let users = objcUsers.map({ $0.map({ $0.user }) })
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.sectionTitles = titles
                self.models = users
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: users.count,
                                          text: R.string.localizable.no_contacts(),
                                          photo: R.image.emptyIndicator.ic_data()!)
                if let searchingKeyword = self.searchingKeyword {
                    self.search(keyword: searchingKeyword)
                }
            }
        }
        queue.addOperation(operation)
    }
    
}

extension ContactViewController: ContainerViewControllerDelegate {
    
    func imageBarRightButton() -> UIImage? {
        showAddContactButton ? R.image.ic_user_add_contact() : nil
    }
    
    func barRightButtonTappedAction() {
        let controller = AddContactViewController.instance()
        navigationController?.pushViewController(controller, animated: true)
    }
    
}
