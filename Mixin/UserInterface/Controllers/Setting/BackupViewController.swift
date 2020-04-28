import UIKit
import WCDBSwift
import MixinServices

class BackupViewController: SettingsTableViewController {
    
    private let backupActionRow = SettingsRow(title: R.string.localizable.setting_backup_now())
    private let backupFilesRow = SettingsRow(title: R.string.localizable.setting_backup_files(),
                                             accessory: .switch(isOn: AppGroupUserDefaults.User.backupFiles))
    private let backupVideosRow = SettingsRow(title: R.string.localizable.setting_backup_videos(),
                                              accessory: .switch(isOn: AppGroupUserDefaults.User.backupVideos))
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [backupActionRow]),
        SettingsSection(footer: R.string.localizable.setting_backup_auto_tips(), rows: [
            SettingsRow(title: R.string.localizable.setting_backup_auto(),
                        subtitle: nil,
                        accessory: .disclosure),
            backupFilesRow,
            backupVideosRow
        ])
    ])
    
    private lazy var autoBackupFrequencyController: UIAlertController = {
        let controller = UIAlertController(title: Localized.SETTING_BACKUP_AUTO, message: Localized.SETTING_BACKUP_AUTO_TIPS, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_DAILY, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .daily
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_WEEKLY, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .weekly
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_MONTHLY, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .monthly
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: Localized.SETTING_BACKUP_OFF, style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .off
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        return controller
    }()
    
    private weak var timer: Timer?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
    
    class func instance() -> UIViewController {
        let vc = BackupViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.setting_backup_title())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableHeaderView = R.nib.backupTableHeaderView(owner: nil)
        updateAutoBackupSubtitle()
        updateActionSectionFooter()
        dataSource.tableViewDelegate = self
        dataSource.tableView = tableView
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateBackupFiles),
                           name: SettingsRow.accessoryDidChangeNotification,
                           object: backupFilesRow)
        center.addObserver(self,
                           selector: #selector(updateBackupVideos),
                           name: SettingsRow.accessoryDidChangeNotification,
                           object: backupVideosRow)
        center.addObserver(self,
                           selector: #selector(backupChanged),
                           name: .BackupDidChange,
                           object: nil)
        
        if BackupJobQueue.shared.isBackingUp || BackupJobQueue.shared.isRestoring {
            updateTableForBackingUp()
        } else if let backupDir = backupUrl, !backupDir.isStoredCloud {
            AppGroupUserDefaults.User.lastBackupDate = nil
            AppGroupUserDefaults.User.lastBackupSize = nil
        }
    }
    
    @objc func backupChanged() {
        timer?.invalidate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateActionSectionFooter()
            self.backupActionRow.accessory = .none
            self.backupActionRow.title = Localized.SETTING_BACKUP_NOW
            if case let .switch(isOn, _) = self.backupFilesRow.accessory {
                self.backupFilesRow.accessory = .switch(isOn: isOn, isEnabled: true)
            }
            if case let .switch(isOn, _) = self.backupVideosRow.accessory {
                self.backupVideosRow.accessory = .switch(isOn: isOn, isEnabled: true)
            }
        }
    }
    
    @objc func updateBackupFiles(_ notification: Notification) {
        guard case let .switch(isOn, _) = backupFilesRow.accessory else {
            return
        }
        AppGroupUserDefaults.User.backupFiles = isOn
    }
    
    @objc func updateBackupVideos(_ notification: Notification) {
        guard case let .switch(isOn, _) = backupVideosRow.accessory else {
            return
        }
        AppGroupUserDefaults.User.backupVideos = isOn
    }
    
}

extension BackupViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && indexPath.row == 0 {
            guard !BackupJobQueue.shared.isBackingUp else {
                return
            }
            if BackupJobQueue.shared.addJob(job: BackupJob(immediatelyBackup: true)) {
                updateTableForBackingUp()
            }
        } else if indexPath.section == 1 && indexPath.row == 0 {
            present(autoBackupFrequencyController, animated: true, completion: nil)
        }
    }
    
}

extension BackupViewController {
    
    private func updateAutoBackupSubtitle() {
        let indexPath = IndexPath(row: 0, section: 1)
        let row = dataSource.row(at: indexPath)
        switch AppGroupUserDefaults.User.autoBackup {
        case .daily:
            row.subtitle = Localized.SETTING_BACKUP_DAILY
        case .weekly:
            row.subtitle = Localized.SETTING_BACKUP_WEEKLY
        case .monthly:
            row.subtitle = Localized.SETTING_BACKUP_MONTHLY
        case .off:
            row.subtitle = Localized.SETTING_BACKUP_OFF
        }
    }
    
    private func updateActionSectionFooter() {
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
        dataSource.sections[0].footer = text
    }
    
    private func updateTableForBackingUp() {
        backupActionRow.accessory = .busy
        if BackupJobQueue.shared.isBackingUp {
            backupActionRow.title = R.string.localizable.setting_backing()
        } else {
            backupActionRow.title = R.string.localizable.setting_restoring()
        }
        if case let .switch(isOn, _) = backupFilesRow.accessory {
            backupFilesRow.accessory = .switch(isOn: isOn, isEnabled: false)
        }
        if case let .switch(isOn, _) = backupVideosRow.accessory {
            backupVideosRow.accessory = .switch(isOn: isOn, isEnabled: false)
        }
        updateActionSectionFooter()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            self?.updateActionSectionFooter()
        })
    }
    
}
