import UIKit
import MixinServices

class BackupViewController: SettingsTableViewController {
    
    private let backupActionRow = SettingsRow(title: R.string.localizable.back_up_now())
    private let backupFilesRow = SettingsRow(title: R.string.localizable.include_files(),
                                             accessory: .switch(isOn: AppGroupUserDefaults.User.backupFiles))
    private let backupVideosRow = SettingsRow(title: R.string.localizable.include_videos(),
                                              accessory: .switch(isOn: AppGroupUserDefaults.User.backupVideos))
    
    private lazy var dataSource = SettingsDataSource(sections: [
        SettingsSection(rows: [backupActionRow]),
        SettingsSection(footer: R.string.localizable.auto_back_up_hint(), rows: [
            SettingsRow(title: R.string.localizable.auto_backup(),
                        subtitle: nil,
                        accessory: .disclosure),
            backupFilesRow,
            backupVideosRow
        ])
    ])
    
    private lazy var autoBackupFrequencyController: UIAlertController = {
        let controller = UIAlertController(title: R.string.localizable.auto_backup(), message: R.string.localizable.auto_back_up_hint(), preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: R.string.localizable.daily(), style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .daily
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.weekly(), style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .weekly
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.monthly(), style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .monthly
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.off(), style: .default, handler: { [weak self] (_) in
            AppGroupUserDefaults.User.autoBackup = .off
            self?.updateAutoBackupSubtitle()
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        return controller
    }()
    
    private lazy var lastBackupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private weak var timer: Timer?
    private var reportRecognizer: UILongPressGestureRecognizer!
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
    
    class func instance() -> UIViewController {
        let vc = BackupViewController()
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_backup())
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
                           name: BackupJob.backupDidChangeNotification,
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
            self.backupActionRow.title = R.string.localizable.back_up_now()
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
            row.subtitle = R.string.localizable.daily()
        case .weekly:
            row.subtitle = R.string.localizable.weekly()
        case .monthly:
            row.subtitle = R.string.localizable.monthly()
        case .off:
            row.subtitle = R.string.localizable.off()
        }
    }
    
    private func updateActionSectionFooter() {
        let text: String?
        if let backupJob = BackupJobQueue.shared.backupJob {
            let preparedProgress = backupJob.preparedProgress
            let totalUploadedSize = backupJob.totalProcessedSize
            if backupJob.isPreparing {
                if preparedProgress == 0 {
                    text = R.string.localizable.preparing()
                } else {
                    let progress = NumberFormatter.simplePercentage.stringFormat(value: preparedProgress)
                    text = R.string.localizable.preparing_progress(progress)
                }
            } else if totalUploadedSize == 0 {
                text = R.string.localizable.uploading()
            } else {
                let totalFileSize = backupJob.totalFileSize
                let uploadProgress = NumberFormatter.simplePercentage.stringFormat(value: Float64(totalUploadedSize) / Float64(totalFileSize))
                text = R.string.localizable.uploading_progress(totalUploadedSize.sizeRepresentation(), totalFileSize.sizeRepresentation(), uploadProgress)
            }
        } else if let restoreJob = BackupJobQueue.shared.restoreJob {
            let number = NSNumber(value: restoreJob.progress)
            let percentage = NumberFormatter.simplePercentage.string(from: number)
            text = R.string.localizable.restoring_progress(percentage ?? "")
        } else {
            if let size = AppGroupUserDefaults.User.lastBackupSize, let date = AppGroupUserDefaults.User.lastBackupDate {
                text = R.string.localizable.last_backup_hint(lastBackupDateFormatter.string(from: date), size.sizeRepresentation())
            } else {
                text = nil
            }
        }
        dataSource.sections[0].footer = text
    }
    
    private func updateTableForBackingUp() {
        backupActionRow.accessory = .busy
        if BackupJobQueue.shared.isBackingUp {
            backupActionRow.title = R.string.localizable.backing_up()
        } else {
            backupActionRow.title = R.string.localizable.restoring()
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
        let alc = UIAlertController(title: R.string.localizable.report_title(), message: AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation(), preferredStyle: .actionSheet)
        alc.addAction(UIAlertAction(title: R.string.localizable.send_to_developer(), style: .default, handler: { (_) in
            self.report()
        }))
        alc.addAction(UIAlertAction(title: R.string.localizable.compress_database(), style: .default, handler: compressDatabase))
        alc.addAction(UIAlertAction(title: R.string.localizable.optimize_database(), style: .default, handler: optimizeDatabase))
        alc.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: nil))
        self.present(alc, animated: true, completion: nil)
    }
    
    private func compressDatabase(_ action: UIAlertAction) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            do {
                Logger.database.info(category: "DB Compressor", message: "Start compressing database, size: \(AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation())")
                try UserDatabase.current.writeAndReturnError { (db) -> Void in
                    try db.checkpoint(.full, on: nil)
                }
                try UserDatabase.current.vacuum()
                Logger.database.info(category: "DB Compressor", message: "Database compression finished, size: \(AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation())")
                DispatchQueue.main.async {
                    hud.set(style: .notification, text: R.string.localizable.compressed())
                    hud.scheduleAutoHidden()
                }
            } catch {
                DispatchQueue.main.async {
                    hud.set(style: .error, text: R.string.localizable.operation_failed())
                    hud.scheduleAutoHidden()
                }
                Logger.database.error(category: "DB Compressor", message: "Compression failed: \(error)")
            }
        }
    }
    
    private func optimizeDatabase(_ action: UIAlertAction) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async {
            do {
                Logger.database.info(category: "DB Optimizer", message: "Start optimizing database")
                try UserDatabase.current.writeAndReturnError { db in
                    _ = try db.checkpoint(.full, on: nil)
                }
                try UserDatabase.current.writeAndReturnError { db in
                    try db.execute(sql: "ANALYZE")
                }
                Logger.database.info(category: "DB Optimizer", message: "Database optimization finished")
                DispatchQueue.main.async {
                    hud.set(style: .notification, text: R.string.localizable.optimized())
                    hud.scheduleAutoHidden()
                }
            } catch {
                DispatchQueue.main.async {
                    hud.set(style: .error, text: R.string.localizable.operation_failed())
                    hud.scheduleAutoHidden()
                }
                Logger.database.error(category: "DB Optimizer", message: "Optimization failed: \(error)")
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
            Logger.general.info(category: "BackupViewController", message: log)
            
            Logger.database.info(category: "BackupViewController", message: "mixin.db size: \(AppGroupContainer.userDatabaseUrl.fileSize.sizeRepresentation())")
            
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
