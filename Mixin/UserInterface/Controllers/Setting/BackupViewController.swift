import UIKit
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
    private var reportRecognizer: UILongPressGestureRecognizer!
    
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
                           name: Application.backupDidChangeNotification,
                           object: nil)
        
        if BackupJobQueue.shared.isBackingUp || BackupJobQueue.shared.isRestoring {
            updateTableForBackingUp()
        } else if let backupDir = backupUrl, !backupDir.isStoredCloud {
            AppGroupUserDefaults.User.lastBackupDate = nil
            AppGroupUserDefaults.User.lastBackupSize = nil
        }
        
        reportRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(showReportMenuAction))
        reportRecognizer.minimumPressDuration = 2
        container?.titleLabel.isUserInteractionEnabled = true
        container?.titleLabel.addGestureRecognizer(reportRecognizer)
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

extension BackupViewController {
    
    @objc func showReportMenuAction() {
        let alc = UIAlertController(title: Localized.REPORT_TITLE, message: AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation(), preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: Localized.REPORT_BUTTON, style: .default, handler: { (_) in
            self.report()
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.report_compress_database(), style: .default, handler: { (_) in
            self.compressDatabase()
        }))
        alc.addAction(UIAlertAction(title: Localized.DIALOG_BUTTON_CANCEL, style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    private func compressDatabase() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            do {
                Logger.writeDatabase(log: "[Database] start compressing ...size:\(AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation())")
                try UserDatabase.current.pool.write({ (db) -> Void in
                    try db.checkpoint(.full, on: nil)
                })
                try UserDatabase.current.pool.vacuum()
                Logger.writeDatabase(log: "[Database] end of compression ...size:\(AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation())")
                DispatchQueue.main.async {
                    hud.set(style: .notification, text: R.string.localizable.report_compress_database_success())
                    hud.scheduleAutoHidden()
                }
            } catch {
                DispatchQueue.main.async {
                    hud.set(style: .error, text: R.string.localizable.error_operation_failed())
                    hud.scheduleAutoHidden()
                }
                Logger.writeDatabase(error: error)
            }
        }
    }
    
    private func report() {
        DispatchQueue.global().async { [weak self] in
            let developID = myIdentityNumber == "762532" ? "31911" : "762532"
            var user = UserDAO.shared.getUser(identityNumber: developID)
            if user == nil {
                switch UserAPI.search(keyword: developID) {
                case let .success(userResponse):
                    UserDAO.shared.updateUsers(users: [userResponse])
                    user = UserItem.createUser(from: userResponse)
                case .failure:
                    return
                }
            }
            guard let developUser = user else {
                return
            }
            
            var log = "\n\(AppGroupContainer.documentsUrl.path)\n"
            log += Self.debugCloudFiles(baseDir: AppGroupContainer.documentsUrl, parentDir: AppGroupContainer.documentsUrl).joined(separator: "\n")
            Logger.write(log: log)
            
            Logger.writeDatabase(log: "[Database] mixin.db size:\(AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation())")
            
            let developConversationId = ConversationDAO.shared.makeConversationId(userId: myUserId, ownerUserId: developUser.userId)
            guard let url = Logger.export(conversationId: developConversationId) else {
                return
            }
            let targetUrl = AttachmentContainer.url(for: .files, filename: url.lastPathComponent)
            do {
                try FileManager.default.copyItem(at: url, to: targetUrl)
                try FileManager.default.removeItem(at: url)
            } catch {
                return
            }
            guard FileManager.default.fileSize(targetUrl.path) > 0 else {
                return
            }
            
            var message = Message.createMessage(category: MessageCategory.PLAIN_DATA.rawValue, conversationId: developConversationId, userId: myUserId)
            message.name = url.lastPathComponent
            message.mediaSize = FileManager.default.fileSize(targetUrl.path)
            message.mediaMimeType = FileManager.default.mimeType(ext: url.pathExtension)
            message.mediaUrl = url.lastPathComponent
            message.mediaStatus = MediaStatus.PENDING.rawValue

            SendMessageService.shared.sendMessage(message: message, ownerUser: developUser, isGroupMessage: false)
            DispatchQueue.main.async {
                self?.navigationController?.pushViewController(withBackRoot: ConversationViewController.instance(ownerUser: developUser))
            }
        }
    }
    
    private static func debugCloudFiles(baseDir: URL, parentDir: URL) -> [String] {
        let files = FileManager.default.childFiles(parentDir)
        var dirs = [String]()
        
        for file in files {
            let url = parentDir.appendingPathComponent(file)
            if FileManager.default.directoryExists(atPath: url.path) {
                dirs.append("[Local][\(url.suffix(base: baseDir))] \(files.count) child files")
                dirs += debugCloudFiles(baseDir: baseDir, parentDir: url)
            } else if file.contains("mixin.db") {
                dirs.append("[Local][\(url.suffix(base: baseDir))] file size:\(url.fileSize.sizeRepresentation())")
            }
        }
        
        return dirs
    }
}
