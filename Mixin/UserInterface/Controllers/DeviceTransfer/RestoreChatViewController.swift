import UIKit
import MixinServices

final class RestoreChatViewController: UIViewController, CheckSessionEnvironmentChild {
    
    @IBOutlet weak var tableView: UITableView!
    
    private var icloudBackupExists: Bool {
        guard let backupURL = backupUrl else {
            return false
        }
        let exists = backupURL.appendingPathComponent(backupDatabaseName).isStoredCloud
            || backupURL.appendingPathComponent("mixin.backup.db").isStoredCloud
        return exists
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(R.nib.restoreChatTableViewCell)
        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
    }
    
    @IBAction func skipButton(_ sender: Any) {
        reporter.report(event: .loginRestore, tags: ["type": "skip"])
        Logger.general.info(category: "RestoreChat", message: "Restoration skipped")
        AppGroupUserDefaults.Account.canRestoreFromPhone = false
        AppGroupUserDefaults.Account.canRestoreMedia = false
        checkSessionEnvironmentAgain()
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "sign_up"])
    }
    
}

extension RestoreChatViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        icloudBackupExists ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.restore_chat, for: indexPath)!
        cell.imageView?.tintColor = R.color.icon_tint()
        if indexPath.section == 0 {
            cell.titleLabel.text = R.string.localizable.restore_from_another_phone()
            cell.detailLabel.text = R.string.localizable.transfer_from_phone_hint()
            cell.imageView?.image = R.image.setting.ic_chat_restore_phone()
        } else {
            cell.titleLabel.text = R.string.localizable.restore_from_icloud()
            cell.detailLabel.text = R.string.localizable.restore_chat_from_icloud()
            cell.imageView?.image = R.image.setting.ic_chat_restore_cloud()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let next: UIViewController
        if indexPath.section == 0 {
            next = RestoreFromPhoneViewController()
            reporter.report(event: .loginRestore, tags: ["type": "another_phone"])
        } else {
            next = RestoreFromCloudViewController()
            reporter.report(event: .loginRestore, tags: ["type": "icloud"])
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        0
    }
    
}
