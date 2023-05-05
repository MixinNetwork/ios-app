import UIKit
import Combine
import MixinServices

class DeviceTransferProgressViewController: UIViewController {
    
    enum Intent {
        
        case transferToDesktop(DeviceTransferServer)
        case transferToPhone(DeviceTransferServer)
        case restoreFromPhone(DeviceTransferCommand, DeviceTransferClient?)
        case restoreFromDesktop(DeviceTransferClient)
        case restoreFromCloud
        
        var image: UIImage? {
            switch self {
            case .transferToDesktop:
                return R.image.setting.ic_transfer_desktop()
            case .transferToPhone:
                return R.image.setting.ic_transfer_phone()
            case .restoreFromDesktop:
                return R.image.setting.ic_restore_desktop()
            case .restoreFromPhone:
                return R.image.setting.ic_transfer_phone()
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
    
    private var intent: Intent
    private var stateObserver: AnyCancellable?
    private var endPoint: DeviceTransferServiceProvidable?
    private var displayAwakeningToken: DisplayAwakener.Token?
    
    init(intent: Intent) {
        self.intent = intent
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
        view.isUserInteractionEnabled = false
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        displayAwakeningToken = DisplayAwakener.shared.retain()
        imageView.image = intent.image
        tipLabel.text = intent.tip
        progressLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        progressLabel.text = intent.title
        Logger.general.info(category: "DeviceTransferProgressViewController", message: "Start transfer: \(intent)")
        switch intent {
        case let .transferToDesktop(server):
            endPoint = server
            stateObserver = server.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] state in
                    self?.stateDidChange(state)
                })
        case let .transferToPhone(server):
            endPoint = server
            stateObserver = server.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] state in
                    self?.stateDidChange(state)
                })
        case let .restoreFromDesktop(client):
            endPoint = client
            stateObserver = client.$displayState
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] state in
                    self?.stateDidChange(state)
                })
        case let .restoreFromPhone(command, _):
            if let ip = command.ip, let port = command.port, let code = command.code {
                let client = DeviceTransferClient(host: ip, port: UInt16(port), code: code)
                stateObserver = client.$displayState
                    .receive(on: DispatchQueue.main)
                    .sink(receiveValue: { [weak self] state in
                        self?.stateDidChange(state)
                    })
                client.start()
                intent = .restoreFromPhone(command, client)
                endPoint = client
            } else {
                alert(R.string.localizable.connection_establishment_failed(), message: nil) { _ in
                    AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
                }
                Logger.general.info(category: "DeviceTransferProgressViewController", message: "Restore from phone failed, ip:\(command.ip ?? ""), port: \(command.port ?? -1), code: \(command.code ?? -1)")
            }
        case .restoreFromCloud:
            restoreFromCloud()
        }
    }
    
}

extension DeviceTransferProgressViewController {
    
    private func stateDidChange(_ state: DeviceTransferDisplayState) {
        switch state {
        case let .transporting(processedCount, totalCount):
            let progressValue = Double(processedCount) / Double(totalCount) * 100
            let progress = String(format: "%.2f", progressValue)
            switch intent {
            case .transferToDesktop, .transferToPhone:
                progressLabel.text = R.string.localizable.transferring_chat_progress(progress)
            case .restoreFromDesktop, .restoreFromPhone:
                progressLabel.text = R.string.localizable.restoring_chat_progress(progress)
            case .restoreFromCloud:
                break
            }
        case .failed(let error):
            stateObserver?.cancel()
            endPoint?.stop()
            let hint: String
            switch error {
            case .mismatchedUserId:
                hint = R.string.localizable.unable_synced_between_different_account()
            case .mismatchedCode:
                hint = R.string.localizable.connection_establishment_failed()
            case .exception, .completed:
                hint = R.string.localizable.transfer_failed()
            }
            progressLabel.text = hint
            transferFailed(hint: hint)
            Logger.general.info(category: "DeviceTransferProgressViewController", message: "Transfer failed: \(error)")
        case .closed:
            stateObserver?.cancel()
            endPoint?.stop()
            let hint: String
            switch intent {
            case .transferToDesktop, .transferToPhone:
                hint = R.string.localizable.transfer_completed()
            case .restoreFromDesktop, .restoreFromPhone:
                hint = R.string.localizable.restore_completed()
            case .restoreFromCloud:
                return
            }
            progressLabel.text = hint
            transferSucceeded(hint: hint)
            Logger.general.info(category: "DeviceTransferProgressViewController", message: "Transfer succeeded")
        case .preparing, .ready, .connected, .finished:
            break
        }
    }
    
    private func transferFailed(hint: String) {
        switch intent {
        case .transferToPhone:
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            alert(hint) { _ in
                self.navigationController?.popViewController(animated: true)
            }
        case .transferToDesktop:
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            alert(hint) { _ in
                self.navigationController?.popViewController(animated: true)
            }
        case .restoreFromPhone, .restoreFromCloud:
            alert(hint) { _ in
                self.navigationController?.popToRootViewController(animated: true)
            }
        case .restoreFromDesktop:
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: nil)
            alert(hint) { _ in
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    private func transferSucceeded(hint: String = "") {
        switch intent {
        case .transferToPhone:
            alert(hint) { _ in
                LoginManager.shared.inDeviceTransfer = false
                LoginManager.shared.loggedOutInDeviceTransfer = false
                LoginManager.shared.logout(reason: "Device Transfer")
            }
        case .transferToDesktop:
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            alert(hint) { _ in
                self.navigationController?.backToHome()
            }
        case .restoreFromDesktop:
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            NotificationCenter.default.post(onMainThread: MixinServices.conversationDidChangeNotification, object: nil)
            alert(hint) { _ in
                self.navigationController?.backToHome()
            }
        case .restoreFromPhone:
            AppGroupUserDefaults.Account.canRestoreFromPhone = false
            AppGroupUserDefaults.Database.isFTSInitialized = false
            AppGroupUserDefaults.User.isCircleSynchronized = false
            UserDatabase.reloadCurrent()
            AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
        case .restoreFromCloud:
            AppGroupUserDefaults.Account.canRestoreMedia = true
            AppGroupUserDefaults.Database.isFTSInitialized = false
            AppGroupUserDefaults.User.needsRebuildDatabase = true
            AppGroupUserDefaults.User.isCircleSynchronized = false
            UserDatabase.reloadCurrent()
            AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
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
                DispatchQueue.main.async {
                    self.transferSucceeded()
                }
            } catch {
                Logger.general.error(category: "DeviceTransferProgressViewController", message: "Restore from icloud, restoration at: \(cloudURL.suffix(base: backupDir)), failed for: \(error)")
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
