import UIKit
import MixinServices

class AddContactViewController: SettingsTableViewController {

    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [
            SettingsRow(title: R.string.localizable.add_by_id_or_phone_number(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.add_by_phone_contacts(), accessory: .disclosure),
            SettingsRow(title: R.string.localizable.add_by_qr_code(), accessory: .disclosure),
        ])
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    class func instance() -> UIViewController {
        let vc = AddContactViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.add_contact())
    }
    
}

extension AddContactViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            let controller = AddPeopleViewController.instance()
            navigationController?.pushViewController(controller, animated: true)
        case 1:
            if ContactsManager.shared.authorization == .authorized {
                let controller = PhoneContactViewController.instance()
                navigationController?.pushViewController(controller, animated: true)
            } else {
                requestPhoneContactAuthorization()
            }
        default:
            showMyQrCode()
        }
    }
    
}

extension AddContactViewController {
    
    private func showMyQrCode() {
        guard let account = LoginManager.shared.account else {
            return
        }
        let qrCode = QRCodeViewController(account: account)
        present(qrCode, animated: true)
    }
    
    private func requestPhoneContactAuthorization() {
        let title: String
        let isNotDetermined = ContactsManager.shared.authorization == .notDetermined
        if isNotDetermined {
            title = R.string.localizable.allow()
        } else {
            title = R.string.localizable.settings()
        }
        let window = AccessPhoneContactHintWindow.instance()
        window.button.setTitle(title, for: .normal)
        window.action = {
            if isNotDetermined {
                ContactsManager.shared.store.requestAccess(for: .contacts, completionHandler: { (granted, error) in
                    guard granted else {
                        return
                    }
                    AppGroupUserDefaults.User.autoUploadsContacts = true
                    PhoneContactAPI.upload(contacts: ContactsManager.shared.contacts, completion: { (result) in
                        switch result {
                        case .success:
                            ContactAPI.syncContacts()
                        case .failure:
                            break
                        }
                    })
                    DispatchQueue.main.async {
                        let controller = PhoneContactViewController.instance()
                        self.navigationController?.pushViewController(controller, animated: true)
                    }
                })
            } else {
                UIApplication.openAppSettings()
            }
        }
        window.presentPopupControllerAnimated()
    }
    
}
