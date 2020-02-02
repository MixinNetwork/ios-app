import UIKit
import WCDBSwift
import MixinServices

class BackupViewController: UITableViewController {
    
    @IBOutlet weak var switchIncludeFiles: UISwitch!
    @IBOutlet weak var switchIncludeVideos: UISwitch!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var backupIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var backupLabel: UILabel!
    
    private let footerReuseId = "footer"
    
    private lazy var actionSectionFooterView = SeparatorShadowFooterView()
    private lazy var autoBackupFrequencyController: UIAlertController = {
        let controller = UIAlertController(title: Localized.SETTING_BACKUP_AUTO, message: Localized.SETTING_BACKUP_AUTO_TIPS, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_DAILY, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .daily
            self?.updateUIOfBackupFrequency()
        }))
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_WEEKLY, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .weekly
            self?.updateUIOfBackupFrequency()
        }))
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_MONTHLY, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .monthly
            self?.updateUIOfBackupFrequency()
        }))
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_OFF, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .off
            self?.updateUIOfBackupFrequency()
        }))
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        return controller
    }()
    
    private var timer: Timer?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        timer = nil
    }
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.backup()!
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_BACKUP_TITLE)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(SeparatorShadowFooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseId)
        tableView.estimatedSectionFooterHeight = 10
        tableView.sectionFooterHeight = UITableView.automaticDimension
        updateTableViewContentInsetBottom()
        switchIncludeFiles.isOn = AppGroupUserDefaults.User.backupFiles
        switchIncludeVideos.isOn = AppGroupUserDefaults.User.backupVideos
        updateUIOfBackupFrequency()
        reloadActionSectionFooterLabel()

        NotificationCenter.default.addObserver(self, selector: #selector(backupChanged), name: .BackupDidChange, object: nil)
        if BackupJobQueue.shared.isBackingUp || BackupJobQueue.shared.isRestoring {
            backingUI()
        } else if let backupDir = backupUrl, !backupDir.isStoredCloud {
            AppGroupUserDefaults.User.lastBackupDate = nil
            AppGroupUserDefaults.User.lastBackupSize = nil
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewContentInsetBottom()
    }
    
    @objc func backupChanged() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.reloadActionSectionFooterLabel()
            self.backupIndicatorView.stopAnimating()
            self.backupLabel.text = Localized.SETTING_BACKUP_NOW
            self.switchIncludeFiles.isEnabled = true
            self.switchIncludeVideos.isEnabled = true
            self.tableView.reloadData()
        }
    }
    
    @IBAction func switchIncludeFiles(_ sender: Any) {
        AppGroupUserDefaults.User.backupFiles = switchIncludeFiles.isOn
    }

    @IBAction func switchIncludeVideos(_ sender: Any) {
        AppGroupUserDefaults.User.backupVideos = switchIncludeVideos.isOn
    }

    private func backingUI() {
        backupIndicatorView.startAnimating()
        backupLabel.text = BackupJobQueue.shared.isBackingUp ? R.string.localizable.setting_backing() : R.string.localizable.setting_restoring()
        switchIncludeFiles.isEnabled = false
        switchIncludeVideos.isEnabled = false
        reloadActionSectionFooterLabel()
        tableView.reloadData()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            self?.reloadActionSectionFooterLabel()
        })
    }
    
    private func reloadActionSectionFooterLabel() {
        let text: String?
        if let backupJob = BackupJobQueue.shared.backupJob {
            if backupJob.isBackingUp {
                if backupJob.backupSize == 0 {
                    text = R.string.localizable.setting_backup_preparing()
                } else {
                    let progress = NumberFormatter.simplePercentage.stringFormat(value: Float64(backupJob.backupSize) / Float64(backupJob.backupTotalSize))
                    text = R.string.localizable.setting_backup_preparing_progress(progress)
                }
            } else if backupJob.uploadedSize == 0 {
                text = R.string.localizable.setting_backup_uploading()
            } else {
                let uploadedSize = backupJob.uploadedSize
                let totalFileSize = backupJob.totalFileSize
                let uploadProgress = NumberFormatter.simplePercentage.stringFormat(value: Float64(uploadedSize) / Float64(totalFileSize))
                text = R.string.localizable.setting_backup_uploading_progress(uploadedSize.sizeRepresentation(), totalFileSize.sizeRepresentation(), uploadProgress)
            }
        } else if let restoreJob = BackupJobQueue.shared.restoreJob {
            let number = NSNumber(value: restoreJob.progress)
            let percentage = NumberFormatter.simplePercentage.string(from: number)
            text = Localized.SETTING_RESTORE_PROGRESS(progress: percentage ?? "")
        } else {
            if let size = AppGroupUserDefaults.User.lastBackupSize, let date = AppGroupUserDefaults.User.lastBackupDate {
                text = Localized.SETTING_BACKUP_LAST(time: DateFormatter.backupFormatter.string(from: date), size: size.sizeRepresentation())
            } else {
                text = nil
            }
        }
        actionSectionFooterView.text = text
    }
    
    private func updateTableViewContentInsetBottom() {
        if view.safeAreaInsets.bottom < 10 {
            tableView.contentInset.bottom = 10
        } else {
            tableView.contentInset.bottom = 0
        }
    }
    
    private func updateUIOfBackupFrequency() {
        switch AppGroupUserDefaults.User.autoBackup {
        case .daily:
            categoryLabel.text = Localized.SETTING_BACKUP_DAILY
        case .weekly:
            categoryLabel.text = Localized.SETTING_BACKUP_WEEKLY
        case .monthly:
            categoryLabel.text = Localized.SETTING_BACKUP_MONTHLY
        case .off:
            categoryLabel.text = Localized.SETTING_BACKUP_OFF
        }
    }
    
}

extension BackupViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 && indexPath.row == 0 {
            guard !BackupJobQueue.shared.isBackingUp else {
                return
            }
            if BackupJobQueue.shared.addJob(job: BackupJob(immediatelyBackup: true)) {
                backingUI()
            }
        } else if indexPath.section == 1 && indexPath.row == 0 {
            present(autoBackupFrequencyController, animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section == 0 {
            return actionSectionFooterView
        } else {
            let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseId) as! SeparatorShadowFooterView
            view.shadowView.hasLowerShadow = false
            view.text = Localized.SETTING_BACKUP_AUTO_TIPS
            return view
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
    
}
