import UIKit
import AVFoundation

class ContactViewController: UITableViewController {

    private var contacts = [UserItem]()
    private var showPhoneContactTips = false
    private var phoneContactSections = [[PhoneContact]]()
    private var sectionIndexTitles = [String]()
    private lazy var phoneContactWindow = PhoneContactWindow.instance()
    private lazy var myQRCodeWindow = MyQRCodeWindow.instance()
    private lazy var receiveMoneyWindow = ReceiveMoneyWindow.instance()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        container?.leftButton.setImage(#imageLiteral(resourceName: "ic_titlebar_chat"), for: .normal)
        tableView.register(UINib(nibName: "PhoneContactHeaderFooter", bundle: nil), forHeaderFooterViewReuseIdentifier: PhoneContactHeaderFooter.cellIdentifier)
        tableView.register(UINib(nibName: "ContactMeCell", bundle: nil), forCellReuseIdentifier: ContactMeCell.cellIdentifier)
        tableView.register(UINib(nibName: "ContactQRCodeCell", bundle: nil), forCellReuseIdentifier: ContactQRCodeCell.cellIdentifier)
        tableView.register(UINib(nibName: "ContactNavCell", bundle: nil), forCellReuseIdentifier: ContactNavCell.cellIdentifier)
        tableView.register(UINib(nibName: "ContactCell", bundle: nil), forCellReuseIdentifier: ContactCell.cellIdentifier)
        tableView.register(UINib(nibName: "PhoneContactCell", bundle: nil), forCellReuseIdentifier: PhoneContactCell.cellIdentifier)
        tableView.register(UINib(nibName: "PhoneContactGuideCell", bundle: nil), forCellReuseIdentifier: PhoneContactGuideCell.cellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.reloadData()
        fetchContacts(refresh: true)
        NotificationCenter.default.addObserver(forName: .AccountDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        }
        NotificationCenter.default.addObserver(forName: .ContactsDidChange, object: nil, queue: .main) { [weak self] (_) in
            self?.fetchContacts(refresh: false)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func settingAction() {
        navigationController?.pushViewController(SettingViewController.instance(), animated: true)
    }

    private func fetchContacts(refresh: Bool = false) {
        DispatchQueue.global().async { [weak self] in
            let contacts = UserDAO.shared.contacts()
            self?.contacts = contacts
            DispatchQueue.main.async {
                UIView.performWithoutAnimation {
                    self?.tableView.reloadSections(IndexSet(integer: 2), with: .none)
                }
                if refresh {
                    self?.checkPhoneContact(contacts)
                }
            }
        }
    }

    class func instance() -> UIViewController {
        return ContainerViewController.instance(viewController: Storyboard.contact.instantiateInitialViewController()!, title: Localized.CONTACT_TITLE)
    }
}

extension ContactViewController: ContainerViewControllerDelegate {

    func barRightButtonTappedAction() {
        settingAction()
    }

    func imageBarRightButton() -> UIImage? {
        return #imageLiteral(resourceName: "ic_titlebar_setting")
    }

}

extension ContactViewController: PhoneContactGuideCellDelegate {

    func requestAccessPhoneContactAction() {
        if ContactsManager.shared.authorization == .notDetermined {
            ContactsManager.shared.store.requestAccess(for: .contacts, completionHandler: { [weak self] (granted, error) in
                guard let weakSelf = self, granted else {
                    return
                }
                PhoneContactAPI.shared.upload(contacts: ContactsManager.shared.contacts, completion: { (result) in
                    switch result {
                    case .success:
                        ContactAPI.shared.syncContacts()
                    case .failure:
                        break
                    }
                })
                weakSelf.fetchPhoneContact(weakSelf.contacts)
            })
        } else {
            UIApplication.openAppSettings()
        }
    }

    private func checkPhoneContact(_ contacts: [UserItem]) {
        if ContactsManager.shared.authorization == .authorized {
            ContactAPI.shared.syncContacts()
            fetchPhoneContact(contacts)
        } else {
            showPhoneContactTips = true
            tableView.reloadSections(IndexSet(integer: 3), with: .none)
        }
    }

    private func fetchPhoneContact(_ contacts: [UserItem]) {
        DispatchQueue.global().async { [weak self] in
            var contactMap = [String: UserItem]()
            for contact in contacts {
                guard let phone = contact.phone, !phone.isEmpty else {
                    continue
                }
                contactMap[phone] = contact
            }

            let phoneContacts = ContactsManager.shared.contacts.filter({ (phoneContact: PhoneContact) -> Bool in
                return contactMap[phoneContact.phoneNumber] == nil
            })

            if let weakSelf = self {
                (weakSelf.sectionIndexTitles, weakSelf.phoneContactSections) = UILocalizedIndexedCollation.current().catalogue(phoneContacts, usingSelector: #selector(getter: PhoneContact.fullName))
            }

            DispatchQueue.main.async {
                self?.showPhoneContactTips = false
                self?.tableView.reloadData()
            }
        }
    }

}

extension ContactViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        if !showPhoneContactTips && sectionIndexTitles.count > 0 {
            return 3 + sectionIndexTitles.count
        }
        return 4
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 2 {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: PhoneContactHeaderFooter.cellIdentifier)! as! PhoneContactHeaderFooter
            header.sectionTitleLabel.text = Localized.CONTACT_TITLE.uppercased()
            return header
        } else if section >= 3 && !showPhoneContactTips && sectionIndexTitles.count > 0 {
            let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: PhoneContactHeaderFooter.cellIdentifier)! as! PhoneContactHeaderFooter
            header.sectionTitleLabel.text = sectionIndexTitles[section - 3]
            return header
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 3 && showPhoneContactTips {
            let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: PhoneContactHeaderFooter.cellIdentifier)! as! PhoneContactHeaderFooter
            footer.sectionTitleLabel.text = Localized.CONTACT_PHONE_CONTACT_SUMMARY
            return footer
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return CGFloat.leastNormalMagnitude
        case 1:
            return 10
        case 2:
            return 30
        default:
            return showPhoneContactTips ? 10 : (sectionIndexTitles.count > 0 ? 30 : 0)
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 3 && showPhoneContactTips {
            return 50
        }
        return 10
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 2
        case 1:
            return 2
        case 2:
            return contacts.count
        default:
            return showPhoneContactTips ? 1 : (phoneContactSections.count > 0 ? phoneContactSections[section - 3].count : 0)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return indexPath.row == 0 ? ContactMeCell.cellHeight : ContactQRCodeCell.cellHeight
        case 1:
            return ContactNavCell.cellHeight
        case 2:
            return ContactCell.cellHeight
        default:
            return showPhoneContactTips ? PhoneContactGuideCell.cellHeight : ContactCell.cellHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: ContactMeCell.cellIdentifier) as! ContactMeCell
                if let account = AccountAPI.shared.account {
                    cell.render(account: account)
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ContactQRCodeCell.cellIdentifier) as! ContactQRCodeCell
                cell.render(separatorColor: tableView.separatorColor!)
                if cell.delegate == nil {
                    cell.delegate = self
                }
                return cell
            }
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: ContactNavCell.cellIdentifier) as! ContactNavCell
            cell.render(row: indexPath.row)
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.cellIdentifier) as! ContactCell
            cell.render(user: contacts[indexPath.row])
            return cell
        default:
            if showPhoneContactTips {
                let cell = tableView.dequeueReusableCell(withIdentifier: PhoneContactGuideCell.cellIdentifier) as! PhoneContactGuideCell
                if cell.delegate == nil {
                    cell.delegate = self
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: PhoneContactCell.cellIdentifier) as! PhoneContactCell
                let section = indexPath.section - 3
                cell.render(contact: phoneContactSections[section][indexPath.row])
                return cell
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            if indexPath.row == 0 {
                navigationController?.pushViewController(MyProfileViewController.instance(), animated: true)
            }
        case 1:
            switch indexPath.row {
            case 0:
                navigationController?.pushViewController(AddMemberViewController.instance(), animated: true)
            case 1:
                navigationController?.pushViewController(AddPeopleViewController.instance(), animated: true)
            default:
                break
            }
        case 2:
            navigationController?.pushViewController(ConversationViewController.instance(ownerUser: contacts[indexPath.row]), animated: true)
        default:
            if showPhoneContactTips {
                requestAccessPhoneContactAction()
            } else {
                let phoneContact = phoneContactSections[indexPath.section - 3][indexPath.row]
                phoneContactWindow.updatePhoneContact(phoneContact: phoneContact).presentView()
            }
            break
        }
    }
}

extension ContactViewController: ContactQRCodeCellDelegate {

    func receiveMoneyAction() {
        receiveMoneyWindow.presentView()
    }

    func myQRCodeAction() {
        myQRCodeWindow.presentView()
    }

}
