import UIKit
import Combine
import MixinServices

class DeviceTransferProgressViewController: UIViewController {
    
    enum Invoker {
        
        case transferToDesktop(DeviceTransferServer)
        case transferToPhone(DeviceTransferServer)
        case restoreFromPhone(DeviceTransferCommand, DeviceTransferClient?)
        case restoreFromDesktop(DeviceTransferClient)
        case restoreFromCloud(Bool)
        
        var image: UIImage? {
            switch self {
            case .transferToDesktop:
                return R.image.setting.ic_transfer_desktop()
            case .transferToPhone:
                return R.image.setting.ic_transfer_phone()
            case .restoreFromDesktop:
                return R.image.setting.ic_restore_desktop()
            case .restoreFromPhone:
                return R.image.setting.ic_restore_phone()
            case .restoreFromCloud:
                return R.image.setting.ic_restore_cloud()
            }
        }
        
        var title: String? {
            switch self {
            case .transferToDesktop, .transferToPhone:
                return R.string.localizable.transferring_chat_progress("0")
            case .restoreFromDesktop, .restoreFromPhone, .restoreFromCloud:
                return R.string.localizable.restoring_chat_progress("0")
            }
        }
        
        var tip: String? {
            switch self {
            case .transferToDesktop, .transferToPhone, .restoreFromDesktop, .restoreFromPhone:
                return R.string.localizable.not_turn_off_screen_hint()
            case .restoreFromCloud:
                return R.string.localizable.restore_chat_history_hint()
            }
        }
        
    }
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var tipLabel: UILabel!
    
    var invoker: Invoker!
    
    private var stateObserver: AnyCancellable?
    private var endPoint: DeviceTransferServiceProvidable?
    private var displayAwakeningToken: DisplayAwakener.Token?
    private var isUsernameJustInitialized: Bool?
    
    deinit {
        if let token = displayAwakeningToken {
            DisplayAwakener.shared.release(token: token)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.isUserInteractionEnabled = false
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        displayAwakeningToken = DisplayAwakener.shared.retain()
        imageView.image = invoker.image
        tipLabel.text = invoker.tip
        progressLabel.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .medium)
        progressLabel.text = invoker.title
        switch invoker {
        case let .transferToDesktop(server):
            endPoint = server
            stateObserver = server.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: stateDidChange(_:))
        case let .transferToPhone(server):
            endPoint = server
            stateObserver = server.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: stateDidChange(_:))
        case let .restoreFromDesktop(client):
            endPoint = client
            stateObserver = client.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: stateDidChange(_:))
        case let .restoreFromPhone(command, _):
            if let ip = command.ip, let port = command.port, let code = command.code {
                let client = DeviceTransferClient(host: ip, port: UInt16(port), code: code)
                stateObserver = client.$displayState
                    .receive(on: DispatchQueue.main)
                    .sink(receiveValue: stateDidChange(_:))
                client.start()
                invoker = .restoreFromPhone(command, client)
                endPoint = client
            } else {
                alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                    AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
                }
            }
        case .restoreFromCloud(let isUsernameJustInitialized):
            self.isUsernameJustInitialized = isUsernameJustInitialized
            restoreFromCloud()
        case .none:
            break
        }
    }
    
}

extension DeviceTransferProgressViewController {
    
    private func stateDidChange(_ state: DeviceTransferDisplayState) {
        switch state {
        case let .transporting(processedCount, totalCount):
            AppGroupUserDefaults.Account.canRestoreChat = false
            let progressValue = Double(processedCount) / Double(totalCount) * 100
            let progress = String(format: "%.1f", progressValue)
            switch invoker {
            case .transferToDesktop, .transferToPhone:
                progressLabel.text = R.string.localizable.transferring_chat_progress(progress)
            case .restoreFromDesktop, .restoreFromPhone:
                progressLabel.text = R.string.localizable.restoring_chat_progress(progress)
            case .restoreFromCloud, .none:
                break
            }
        case .failed(let error):
            stateObserver?.cancel()
            endPoint?.stop()
            let title: String
            switch error {
            case .mismatchedUserId:
                title = R.string.localizable.unable_synced_between_different_account()
            case .mismatchedCode:
                title = R.string.localizable.connection_establishment_failed()
            case .exception, .completed:
                title = R.string.localizable.transfer_failed()
            }
            progressLabel.text = title
            backtoHome(title: title)
        case .closed:
            stateObserver?.cancel()
            endPoint?.stop()
            let title: String
            switch invoker {
            case .transferToDesktop, .transferToPhone:
                title = R.string.localizable.transfer_completed()
            case .restoreFromDesktop, .restoreFromPhone:
                title = R.string.localizable.restore_completed()
            case .restoreFromCloud, .none:
                return
            }
            progressLabel.text = title
            backtoHome(title: title)
        case .preparing, .ready, .connected, .finished:
            break
        }
    }
    
    private func backtoHome(title: String) {
        switch invoker {
        case .transferToPhone:
            LoginManager.shared.inDeviceTrasnfer = false
            LoginManager.shared.loggedOutInDeviceTrasnfer = false
            LoginManager.shared.logout(reason: "Device Transfer")
        case .restoreFromPhone:
            UserDatabase.reloadCurrent()
            AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
        case .transferToDesktop, .restoreFromDesktop:
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: nil)
            alert(title, message: nil) { _ in
                self.navigationController?.backToHome()
            }
        case .restoreFromCloud, .none:
            break
        }
    }
    
}

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
                Logger.general.info(category: "DeviceTransferProgressViewController", message: "Restore from icloud, Missing file: \(cloudURL.suffix(base: backupDir))")
                reporter.report(error: MixinError.missingBackup)
                return
            }
            let localURL = AppGroupContainer.userDatabaseUrl
            do {
                if !cloudURL.isDownloaded {
                    try self.downloadFromCloud(cloudURL: cloudURL, progress: { (progress) in
                        self.progressLabel.text = R.string.localizable.restoring_chat_progress(String(format: "%.1f", progress))
                    })
                } else {
                    Logger.general.info(category: "DeviceTransferProgressViewController", message: "Restore from icloud, file not downloaded: \(cloudURL.suffix(base: backupDir))")
                }
                if FileManager.default.fileExists(atPath: localURL.path) {
                    UserDatabase.closeCurrent()
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.copyItem(at: cloudURL, to: localURL)
                
                AppGroupUserDefaults.Account.canRestoreChat = false
                AppGroupUserDefaults.Account.canRestoreMedia = true
                AppGroupUserDefaults.Database.isSentSenderKeyCleared = false
                AppGroupUserDefaults.Database.isFTSInitialized = false
                AppGroupUserDefaults.User.needsRebuildDatabase = true
                AppGroupUserDefaults.User.isCircleSynchronized = false
                
                UserDatabase.reloadCurrent()
                DispatchQueue.main.async {
                    AppDelegate.current.mainWindow.rootViewController = makeInitialViewController(isUsernameJustInitialized: self.isUsernameJustInitialized ?? false)
                }
            } catch {
                Logger.general.error(category: "DeviceTransferProgressViewController", message: "Restore from icloud, restoration at: \(cloudURL.suffix(base: backupDir)), failed for: \(error)")
                self.restoreFailed(error: error)
            }
        }
    }
    
    private func restoreFailed(error: Swift.Error) {
        reporter.report(error: error)
        backtoHome(title: R.string.localizable.restore_chat_history_failed())
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
