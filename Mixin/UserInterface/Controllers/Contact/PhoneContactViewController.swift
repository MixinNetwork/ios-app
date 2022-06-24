import UIKit
import MessageUI
import MixinServices

class PhoneContactViewController: PeerViewController<[PhoneContact], PhoneContactCell, PhoneContactSearchResult> {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsSelection = false
        searchBoxView.textField.placeholder = R.string.localizable.name_or_phone_number()
    }
    
    override func initData() {
        initDataOperation.addExecutionBlock { [weak self] in
            let contacts = UserDAO.shared.contactsWithoutApp()
            let contactPhoneNumbers = Set(contacts.compactMap({ $0.phone }))
            let phoneContacts = ContactsManager.shared.contacts
                .filter({ !contactPhoneNumbers.contains($0.phoneNumber) })
            let (titles, catalogedContacts) = UILocalizedIndexedCollation.current()
                .catalogue(phoneContacts, usingSelector: #selector(getter: PhoneContact.fullName))
            DispatchQueue.main.sync {
                guard let self = self else {
                    return
                }
                self.sectionTitles = titles
                self.models = catalogedContacts
                self.tableView.reloadData()
                self.tableView.checkEmpty(dataCount: catalogedContacts.count,
                                          text: R.string.localizable.no_contacts(),
                                          photo: R.image.emptyIndicator.ic_data()!)
            }
        }
        queue.addOperation(initDataOperation)
    }
    
    override func search(keyword: String) {
        queue.operations
            .filter({ $0 != initDataOperation })
            .forEach({ $0.cancel() })
        let op = BlockOperation()
        let users = self.models
        op.addExecutionBlock { [unowned op, weak self] in
            guard self != nil, !op.isCancelled else {
                return
            }
            let searchResult = users.flatMap({ $0 })
                .filter({ $0.matches(lowercasedKeyword: keyword) })
                .map({ PhoneContactSearchResult(contact: $0, keyword: keyword) })
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
    
    override func configure(cell: PhoneContactCell, at indexPath: IndexPath) {
        super.configure(cell: cell, at: indexPath)
        cell.delegate = self
        if isSearching {
            cell.render(result: searchResults[indexPath.row])
        } else {
            let contact = models[indexPath.section][indexPath.row]
            cell.render(phoneContact: contact)
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isSearching ? searchResults.count : models[section].count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        isSearching ? 1 : sectionTitles.count
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        isSearching ? nil : sectionTitles
    }
    
    class func instance() -> UIViewController {
        let controller = PhoneContactViewController()
        return ContainerViewController.instance(viewController: controller, title: R.string.localizable.add_by_phone_contacts())
    }
    
}

extension PhoneContactViewController: PhoneContactCellDelegate {
    
    func phoneContactCellDidSelectInvite(_ cell: PhoneContactCell) {
        if MFMessageComposeViewController.canSendText() {
            guard let indexPath = tableView.indexPath(for: cell) else {
                return
            }
            let phoneContact: PhoneContact
            if isSearching {
                phoneContact = searchResults[indexPath.row].contact
            } else {
                phoneContact = models[indexPath.section][indexPath.row]
            }
            let controller = MFMessageComposeViewController()
            controller.body = R.string.localizable.contact_invite_content()
            controller.recipients = [phoneContact.phoneNumber]
            controller.messageComposeDelegate = self
            present(controller, animated: true, completion: nil)
        } else {
            let controller = UIActivityViewController(activityItems: [R.string.localizable.contact_invite_content()],
                                                      applicationActivities: nil)
            present(controller, animated: true, completion: nil)
        }
    }
    
}

extension PhoneContactViewController: MFMessageComposeViewControllerDelegate {
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}
