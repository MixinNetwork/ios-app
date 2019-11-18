import UIKit

final class ContactSettingViewController: UITableViewController {

    private let footerReuseId = "footer"

    private lazy var hud = Hud()

    private var hasUploadMobileContacts: Bool {
        return AppGroupUserDefaults.User.autoUploadsContacts
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.contacts()!
        let container = ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_contacts_title())
        return container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(R.nib.settingCell)
        tableView.register(SeparatorShadowFooterView.self,
                           forHeaderFooterViewReuseIdentifier: footerReuseId)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!

        let hasUploadMobileContacts = self.hasUploadMobileContacts
        cell.titleLabel.text = hasUploadMobileContacts ?  R.string.localizable.setting_contacts_delete() : R.string.localizable.setting_contacts_upload()
        cell.accessoryImageView.isHidden = true
        cell.titleLabel.textColor = hasUploadMobileContacts ? .walletRed : .theme
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
        view.shadowView.hasLowerShadow = false
        return view
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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

    private func uploadContact(isUpload: Bool, contacts: [PhoneContact]) {
        guard let navigationController = navigationController else {
            return
        }
        let hud = self.hud
        hud.show(style: .busy, text: "", on: navigationController.view)

        PhoneContactAPI.shared.upload(contacts: contacts, completion: { [weak self](result) in
            switch result {
            case .success:
                hud.hide()
                AppGroupUserDefaults.User.autoUploadsContacts = isUpload
                self?.tableView.reloadData()
                if isUpload {
                    ContactAPI.shared.syncContacts()
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        })
    }

}
