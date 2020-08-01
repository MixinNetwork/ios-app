import UIKit
import MixinServices

final class PhoneContactsSettingViewController: SettingsTableViewController {
    
    private let dataSource = SettingsDataSource(sections: [])
    
    private lazy var hud = Hud()
    private lazy var uploadSection = SettingsSection(rows: [
        SettingsRow(title: R.string.localizable.setting_contacts_upload(),
                    titleStyle: .highlighted)
    ])
    private lazy var deleteSection = SettingsSection(rows: [
        SettingsRow(title: R.string.localizable.setting_contacts_delete(),
                    titleStyle: .destructive)
    ])
    
    private var hasUploadMobileContacts: Bool {
        return AppGroupUserDefaults.User.autoUploadsContacts
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func instance() -> UIViewController {
        let vc = PhoneContactsSettingViewController()
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_contacts_title())
        return container
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.phoneContactsSettingTableHeaderView(owner: nil)
        reloadData()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
    }
    
    private func reloadData() {
        if hasUploadMobileContacts {
            dataSource.reloadSections([deleteSection])
        } else {
            dataSource.reloadSections([uploadSection])
        }
    }
    
    private func uploadContact(isUpload: Bool, contacts: [PhoneContact]) {
        guard let navigationController = navigationController else {
            return
        }
        let hud = self.hud
        hud.show(style: .busy, text: "", on: navigationController.view)
        PhoneContactAPI.upload(contacts: contacts, completion: { [weak self](result) in
            switch result {
            case .success:
                hud.hide()
                AppGroupUserDefaults.User.autoUploadsContacts = isUpload
                self?.reloadData()
                if isUpload {
                    ContactAPI.syncContacts()
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        })
    }
    
}

extension PhoneContactsSettingViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if hasUploadMobileContacts {
            let alert = UIAlertController(title: R.string.localizable.setting_contacts_delete_confirm(), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: R.string.localizable.menu_delete(), style: .default, handler: { (_) in
                self.uploadContact(isUpload: false, contacts: [])
            }))
            present(alert, animated: true, completion: nil)
        } else {
            uploadContact(isUpload: true, contacts: ContactsManager.shared.contacts)
        }
    }
    
}
