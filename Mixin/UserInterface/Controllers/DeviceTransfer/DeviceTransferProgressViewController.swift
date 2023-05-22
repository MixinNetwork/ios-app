import UIKit
import Combine
import MixinServices

class DeviceTransferProgressViewController: UIViewController {
    
    enum Remote {
        case phone
        case desktop
    }
    
    enum Connection {
        case cloud
        case server(DeviceTransferServer, Remote)
        case client(DeviceTransferClient, Remote)
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tipLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var speedLabel: UILabel!
    
    private let connection: Connection
    
    private var displayAwakeningToken: DisplayAwakener.Token?
    private var stateObserver: AnyCancellable?
    
    init(connection: Connection) {
        self.connection = connection
        let nib = R.nib.deviceTransferProgressView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    deinit {
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.general.info(category: "DeviceTransferProgress", message: "Start transfer: \(connection)")
        view.isUserInteractionEnabled = false
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        displayAwakeningToken = DisplayAwakener.shared.retain()
        titleLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        switch connection {
        case .cloud:
            imageView.image = R.image.setting.ic_restore_cloud()
            titleLabel.text = R.string.localizable.restoring_chat_progress("0")
            tipLabel.text = R.string.localizable.restore_chat_history_hint()
            restoreFromCloud()
        case let .server(server, remote):
            switch remote {
            case .phone:
                imageView.image = R.image.setting.ic_transfer_phone()
            case .desktop:
                imageView.image = R.image.setting.ic_transfer_phone()
            }
            titleLabel.text = R.string.localizable.transferring_chat_progress("0")
            tipLabel.text = R.string.localizable.not_turn_off_screen_hint()
            stateObserver = server.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.serverStateDidChange(state)
                }
        case let .client(client, remote):
            switch remote {
            case .phone:
                imageView.image = R.image.setting.ic_transfer_phone()
            case .desktop:
                imageView.image = R.image.setting.ic_restore_desktop()
            }
            titleLabel.text = R.string.localizable.restoring_chat_progress("0")
            tipLabel.text = R.string.localizable.not_turn_off_screen_hint()
            stateObserver = client.$state
                .receive(on: DispatchQueue.main)
                .sink { [weak self] state in
                    self?.clientStateDidChange(state)
                }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    private func transferFailed(hint: String) {
        switch connection {
        case .server(_, .phone):
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            alert(hint) { _ in
                self.navigationController?.popViewController(animated: true)
                Logger.general.info(category: "DeviceTransferProgress", message: "\(self.connection) failed and popped")
            }
        case .server(_, .desktop):
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            alert(hint) { _ in
                self.navigationController?.popViewController(animated: true)
                Logger.general.info(category: "DeviceTransferProgress", message: "\(self.connection) failed and popped")
            }
        case .client(_, .phone), .cloud:
            alert(hint) { _ in
                self.navigationController?.popToRootViewController(animated: true)
                Logger.general.info(category: "DeviceTransferProgress", message: "\(self.connection) failed and popped")
            }
        case .client(_, .desktop):
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: nil)
            alert(hint) { _ in
                self.navigationController?.popViewController(animated: true)
                Logger.general.info(category: "DeviceTransferProgress", message: "\(self.connection) failed and popped")
            }
        }
    }
    
    private func transferSucceeded(hint: String = "") {
        switch connection {
        case .server(_, .phone):
            alert(hint) { _ in
                LoginManager.shared.inDeviceTransfer = false
                LoginManager.shared.loggedOutInDeviceTransfer = false
                LoginManager.shared.logout(reason: "Device Transfer")
            }
        case .server(_, .desktop):
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            alert(hint) { _ in
                self.navigationController?.backToHome()
            }
        case .client(_, .desktop):
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: nil)
            alert(hint) { _ in
                self.navigationController?.backToHome()
            }
        case .client(_, .phone):
            AppGroupUserDefaults.Account.canRestoreFromPhone = false
            AppGroupUserDefaults.Database.isFTSInitialized = false
            AppGroupUserDefaults.User.isCircleSynchronized = false
            UserDatabase.reloadCurrent()
            AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
        case .cloud:
            AppGroupUserDefaults.Account.canRestoreMedia = true
            AppGroupUserDefaults.Database.isFTSInitialized = false
            AppGroupUserDefaults.User.needsRebuildDatabase = true
            AppGroupUserDefaults.User.isCircleSynchronized = false
            UserDatabase.reloadCurrent()
            AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
        }
    }
    
}

// MARK: - State Handling
extension DeviceTransferProgressViewController {
    
    private func serverStateDidChange(_ state: DeviceTransferServer.State) {
        switch state {
        case .idle, .listening:
            Logger.general.error(category: "DeviceTransferProgress", message: "Invalid state: \(state)")
        case let .transfer(progress, speed):
            updateTitleLabel(with: progress, speed: speed)
        case let .closed(reason):
            handleConnectionClosing(reason: reason)
        }
    }
    
    private func clientStateDidChange(_ state: DeviceTransferClient.State) {
        switch state {
        case .idle, .connecting:
            Logger.general.warn(category: "DeviceTransferProgress", message: "Invalid state: \(state)")
        case let .transfer(progress, speed):
            updateTitleLabel(with: progress, speed: speed)
        case let .closed(reason):
            handleConnectionClosing(reason: reason)
        }
    }
    
    private func updateTitleLabel(with transferProgress: Double, speed: String) {
        let progress = String(format: "%.2f", transferProgress)
        switch connection {
        case .server:
            titleLabel.text = R.string.localizable.transferring_chat_progress(progress)
        case .client:
            titleLabel.text = R.string.localizable.restoring_chat_progress(progress)
        case .cloud:
            break
        }
        progressView.progress = Float(transferProgress / 100)
        speedLabel.text = speed
    }
    
    private func handleConnectionClosing(reason: DeviceTransferClosedReason) {
        switch reason {
        case .finished:
            let hint: String
            switch connection {
            case .server:
                hint = R.string.localizable.transfer_completed()
            case .client:
                hint = R.string.localizable.restore_completed()
            case .cloud:
                return
            }
            titleLabel.text = hint
            progressView.progress = 1
            transferSucceeded(hint: hint)
            speedLabel.isHidden = true
            stateObserver?.cancel()
            Logger.general.info(category: "DeviceTransferProgress", message: "Transfer succeeded")
        case .exception(let error):
            let hint = R.string.localizable.transfer_failed()
            titleLabel.text = hint
            transferFailed(hint: hint)
            speedLabel.isHidden = true
            stateObserver?.cancel()
            Logger.general.info(category: "DeviceTransferProgress", message: "Transfer failed: \(error)")
        }
    }
    
}

// MARK: - Cloud Worker
extension DeviceTransferProgressViewController {
    
    private func restoreFromCloud() {
        DispatchQueue.global().async {
            guard FileManager.default.ubiquityIdentityToken != nil else {
                return
            }
            guard let backupDir = backupUrl else {
                return
            }
            var cloudURL = backupDir.appendingPathComponent(backupDatabaseName)
            if !cloudURL.isStoredCloud {
                cloudURL = backupDir.appendingPathComponent("mixin.backup.db")
            }
            guard cloudURL.isStoredCloud else {
                Logger.general.info(category: "DeviceTransferProgress", message: "Restore from icloud, Missing file: \(cloudURL.suffix(base: backupDir))")
                reporter.report(error: MixinError.missingBackup)
                return
            }
            let localURL = AppGroupContainer.userDatabaseUrl
            do {
                if !cloudURL.isDownloaded {
                    try self.downloadFromCloud(cloudURL: cloudURL, progress: { (progress) in
                        self.progressView.progress = progress
                        self.titleLabel.text = R.string.localizable.restoring_chat_progress(String(format: "%.1f", progress))
                    })
                } else {
                    Logger.general.info(category: "DeviceTransferProgress", message: "Restore from icloud, file not downloaded: \(cloudURL.suffix(base: backupDir))")
                }
                if FileManager.default.fileExists(atPath: localURL.path) {
                    UserDatabase.closeCurrent()
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.copyItem(at: cloudURL, to: localURL)
                DispatchQueue.main.async {
                    self.transferSucceeded()
                }
            } catch {
                Logger.general.error(category: "DeviceTransferProgress", message: "Restore from icloud, restoration at: \(cloudURL.suffix(base: backupDir)), failed for: \(error)")
                if FileManager.default.fileExists(atPath: localURL.path) {
                    UserDatabase.closeCurrent()
                    try? FileManager.default.removeItem(at: localURL)
                }
                UserDatabase.reloadCurrent()
                DispatchQueue.main.async {
                    self.transferFailed(hint: R.string.localizable.restore_chat_history_failed())
                }
                reporter.report(error: error)
            }
        }
    }
    
    private func downloadFromCloud(cloudURL: URL, progress: @escaping (Float) -> Void) throws {
        guard !cloudURL.isDownloaded else {
            progress(1)
            return
        }
        try FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
        
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDataScope]
        query.predicate = NSPredicate(format: "%K LIKE[CD] %@", NSMetadataItemPathKey, cloudURL.path)
        query.valueListAttributes = [NSMetadataUbiquitousItemPercentDownloadedKey,
                                     NSMetadataUbiquitousItemDownloadingStatusKey]
        
        let semaphore = DispatchSemaphore(value: 0)
        let observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: nil, queue: .main) { (notification) in
            guard let metadataItem = (notification.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem])?.first else {
                return
            }
            
            if let percent = metadataItem.value(forAttribute: NSMetadataUbiquitousItemPercentDownloadedKey) as? Double, percent > 1 {
                progress(Float(percent) / 100)
            }
            if let status = metadataItem.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String {
                guard status == NSMetadataUbiquitousItemDownloadingStatusCurrent else {
                    return
                }
                query.stop()
                semaphore.signal()
            }
        }
        DispatchQueue.main.async {
            query.start()
        }
        semaphore.wait()
        NotificationCenter.default.removeObserver(observer)
    }
    
}

// MARK: - Log
extension DeviceTransferProgressViewController {
    
    @objc private func applicationDidEnterBackground() {
        Logger.general.info(category: "DeviceTransferProgress", message: "Did enter background")
    }
    
}
