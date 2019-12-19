import UIKit
import MessageUI

class ContactViewController: UITableViewController {
    
    enum ReuseId {
        static let header = "header"
        static let contact = "contact"
        static let phoneContact = "phone_contact"
        static let upload = "upload"
        static let footer = "footer"
    }
    
    @IBOutlet weak var accountAvatarView: AvatarImageView!
    @IBOutlet weak var accountNameLabel: UILabel!
    @IBOutlet weak var accountIdLabel: UILabel!
    
    private var contacts = [UserItem]()
    private var phoneContacts = [[PhoneContact]]()
    private var phoneContactSectionTitles = [String]()
    
    private var isPhoneContactAuthorized: Bool {
        return ContactsManager.shared.authorization == .authorized
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(resource: R.nib.contactHeaderView), forHeaderFooterViewReuseIdentifier: ReuseId.header)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: ReuseId.footer)
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 10
        updateTableViewContentInsetBottom()
        reloadAccount()
        reloadContacts()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadAccount), name: .AccountDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadContacts), name: .ContactsDidChange, object: nil)
        ContactAPI.shared.syncContacts()
        
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    @IBAction func showAccountAction(_ sender: Any) {
        guard let account = Account.current else {
            return
        }
        let user = UserItem.createUser(from: account)
        let vc = UserProfileViewController(user: user)
        present(vc, animated: true, completion: nil)
    }
    
    @IBAction func newGroupAction(_ sender: Any) {
        let vc = AddMemberViewController.instance()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func addContactAction(_ sender: Any) {
        let vc = AddPeopleViewController.instance()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc func reloadAccount() {
        guard let account = Account.current else {
            return
        }
        DispatchQueue.main.async {
            self.accountAvatarView.setImage(with: account.avatar_url, userId: account.user_id, name: account.full_name)
            self.accountNameLabel.text = account.full_name
            self.accountIdLabel.text = Localized.CONTACT_IDENTITY_NUMBER(identityNumber: account.identity_number)
        }
    }
    
    @objc func reloadContacts() {
        DispatchQueue.global().async { [weak self] in
            let contacts = UserDAO.shared.contacts()
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.contacts = contacts
                weakSelf.tableView.reloadData()
                weakSelf.reloadPhoneContacts()
            }
        }
    }
    
    class func instance() -> UIViewController {
        let vc = Storyboard.contact.instantiateInitialViewController()!
        let container = ContainerViewController.instance(viewController: vc, title: Localized.CONTACT_TITLE)
        return container
    }
    
}

extension ContactViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let vc = SettingViewController.instance()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_title_settings")
    }
    
}

extension ContactViewController {
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return contacts.count
        } else {
            if isPhoneContactAuthorized {
                if phoneContacts.isEmpty {
                    return 0
                } else {
                    return phoneContacts[section - 1].count
                }
            } else {
                return 1
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.contact, for: indexPath) as! ContactCell
            let user = contacts[indexPath.row]
            cell.render(user: user)
            return cell
        } else {
            if isPhoneContactAuthorized {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseId.phoneContact, for: indexPath) as! PhoneContactCell
                let contact = phoneContacts[indexPath.section - 1][indexPath.row]
                cell.render(contact: contact)
                cell.delegate = self
                return cell
            } else {
                return tableView.dequeueReusableCell(withIdentifier: ReuseId.upload, for: indexPath)
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if isPhoneContactAuthorized {
            return 1 + phoneContactSectionTitles.count
        } else {
            return 2
        }
    }
    
}

extension ContactViewController {
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let additionalBottomMargin: CGFloat = 15
        if indexPath.section == 0 {
            if indexPath.row == self.tableView(tableView, numberOfRowsInSection: 0) - 1 {
                return PhoneContactCell.height + additionalBottomMargin
            } else {
                return PhoneContactCell.height
            }
        } else {
            if isPhoneContactAuthorized {
                let lastSection = numberOfSections(in: tableView) - 1
                let lastRow = self.tableView(tableView, numberOfRowsInSection: lastSection) - 1
                if indexPath == IndexPath(row: lastRow, section: lastSection) {
                    return PhoneContactCell.height + additionalBottomMargin
                } else {
                    return PhoneContactCell.height
                }
            } else {
                return UploadContactCell.height
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return contacts.isEmpty ? .leastNormalMagnitude : 41
        } else {
            if isPhoneContactAuthorized {
                if section == 1 || section == numberOfSections(in: tableView) - 1 {
                    return 41
                } else {
                    return 36
                }
            } else {
                return .leastNormalMagnitude
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            if contacts.isEmpty {
                return nil
            } else {
                let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! ContactHeaderView
                view.label.text = Localized.CONTACT_TITLE.uppercased()
                return view
            }
        } else if isPhoneContactAuthorized {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.header) as! ContactHeaderView
            if section == 1 {
                view.label.text = Localized.CONTACT_PHONE_CONTACTS
            } else {
                view.label.text = phoneContactSectionTitles[section - 1]
            }
            return view
        } else {
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseId.footer) as! SeparatorShadowFooterView
        if section == 0 {
            if contacts.isEmpty {
                return nil
            } else {
                let nextSectionHasNoCell = isPhoneContactAuthorized && phoneContacts.isEmpty
                view.shadowView.hasLowerShadow = !nextSectionHasNoCell
                return view
            }
        } else {
            view.shadowView.hasLowerShadow = false
            if isPhoneContactAuthorized {
                if section == phoneContacts.count {
                    return view
                } else {
                    return nil
                }
            } else {
                view.text = Localized.CONTACT_PHONE_CONTACT_SUMMARY
                return view
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if (section == 0 && contacts.isEmpty) || (section != 0 && isPhoneContactAuthorized && section != phoneContacts.count) {
            return .leastNormalMagnitude
        } else {
            return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let contact = contacts[indexPath.row]
            let vc = ConversationViewController.instance(ownerUser: contact)
            navigationController?.pushViewController(vc, animated: true)
        } else if !isPhoneContactAuthorized {
            requestPhoneContactAuthorization()
        }
    }
    
}

extension ContactViewController: PhoneContactCellDelegate {
    
    func phoneContactCellDidSelectInvite(_ cell: PhoneContactCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }
        let phoneContact = phoneContacts[indexPath.section - 1][indexPath.row]
        if MFMessageComposeViewController.canSendText() {
            let vc = MFMessageComposeViewController()
            vc.body = Localized.CONTACT_INVITE
            vc.recipients = [phoneContact.phoneNumber]
            vc.messageComposeDelegate = self
            present(vc, animated: true, completion: nil)
        } else {
            let inviteController = UIActivityViewController(activityItems: [Localized.CONTACT_INVITE],
                                                            applicationActivities: nil)
            present(inviteController, animated: true, completion: nil)
        }
    }
    
}

extension ContactViewController: MFMessageComposeViewControllerDelegate {
    
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
    
}

extension ContactViewController {
    
    private func updateTableViewContentInsetBottom() {
        if view.safeAreaInsets.bottom > 20 {
            tableView.contentInset.bottom = 0
        } else {
            tableView.contentInset.bottom = 20
        }
    }
    
    private func reloadPhoneContacts() {
        guard isPhoneContactAuthorized else {
            return
        }
        let contacts = self.contacts
        DispatchQueue.global().async { [weak self] in
            let contactPhoneNumbers = Set(contacts.compactMap({ $0.phone }))
            let phoneContacts = ContactsManager.shared.contacts
                .filter({ !contactPhoneNumbers.contains($0.phoneNumber) })
            let (titles, catalogedContacts) = UILocalizedIndexedCollation.current()
                .catalogue(phoneContacts, usingSelector: #selector(getter: PhoneContact.fullName))
            DispatchQueue.main.sync {
                guard let weakSelf = self else {
                    return
                }
                weakSelf.phoneContacts = catalogedContacts
                weakSelf.phoneContactSectionTitles = titles
                weakSelf.tableView.reloadData()
            }
        }
    }
    
    private func requestPhoneContactAuthorization() {
        if ContactsManager.shared.authorization == .notDetermined {
            ContactsManager.shared.store.requestAccess(for: .contacts, completionHandler: { (granted, error) in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                AppGroupUserDefaults.User.autoUploadsContacts = true
                PhoneContactAPI.shared.upload(contacts: ContactsManager.shared.contacts, completion: { (result) in
                    switch result {
                    case .success:
                        ContactAPI.shared.syncContacts()
                    case .failure:
                        break
                    }
                })
                self.reloadPhoneContacts()
            })
        } else {
            UIApplication.openAppSettings()
        }
    }
    
}
