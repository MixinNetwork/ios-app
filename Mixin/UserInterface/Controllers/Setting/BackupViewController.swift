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

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        
        if BackupJobQueue.shared.isBackingUp || BackupJobQueue.shared.isRestoring {
            updateTableForBackingUp()
        } else if let backupDir = backupUrl, !backupDir.isStoredCloud {
            AppGroupUserDefaults.User.lastBackupDate = nil
            AppGroupUserDefaults.User.lastBackupSize = nil
        }

        if BackupJobQueue.shared.isBackingUp {
            BackupJobQueue.shared.backupJob?.checkUploadStatus()
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
        if let restoreJob = BackupJobQueue.shared.restoreJob {
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

        BackupJobQueue.shared.backupJob?.backupProgress = { [weak self](copyProgress, uploadedSize, totalFileSize) in
            guard let weakself = self else {
                return
            }
            var text: String?
            if copyProgress == 0 {
                text = R.string.localizable.setting_backup_preparing()
            } else if copyProgress < 100 {
                text = R.string.localizable.setting_backup_preparing_progress(NumberFormatter.simplePercentage.stringFormat(value: copyProgress))
            } else if uploadedSize == 0 {
                text = R.string.localizable.setting_backup_uploading()
            } else if uploadedSize >= totalFileSize {
                weakself.updateActionSectionFooter()
                weakself.backupActionRow.accessory = .none
                weakself.backupActionRow.title = Localized.SETTING_BACKUP_NOW
                if case let .switch(isOn, _) = weakself.backupFilesRow.accessory {
                    weakself.backupFilesRow.accessory = .switch(isOn: isOn, isEnabled: true)
                }
                if case let .switch(isOn, _) = weakself.backupVideosRow.accessory {
                    weakself.backupVideosRow.accessory = .switch(isOn: isOn, isEnabled: true)
                }
            } else {
                let uploadProgress = NumberFormatter.simplePercentage.stringFormat(value: Float64(uploadedSize) / Float64(totalFileSize))
                text = R.string.localizable.setting_backup_uploading_progress(uploadedSize.sizeRepresentation(), totalFileSize.sizeRepresentation(), uploadProgress)
            }
            weakself.dataSource.sections[0].footer = text
        }
    }
    
}
