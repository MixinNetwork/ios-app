import UIKit
import MixinServices

class DatabaseUpgradeViewController: UIViewController {
    
    class var needsUpgrade: Bool {
        !AppGroupUserDefaults.isDocumentsMigrated
            || AppGroupUserDefaults.User.needsUpgradeInMainApp
    }
    
    class func instance(isUsernameJustInitialized: Bool) -> DatabaseUpgradeViewController {
        let controller = R.storyboard.home.database()!
        controller.isUsernameJustInitialized = isUsernameJustInitialized
        return controller
    }
    
    private var isUpgrading = false
    private var isUsernameJustInitialized = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        upgrade()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func upgrade() {
        Logger.general.info(category: "DatabaseUpgrade", message: "Begin upgrade with app state: \(UIApplication.shared.applicationStateString)")
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        guard !isUpgrading else {
            return
        }
        isUpgrading = true
        
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            let localVersion = AppGroupUserDefaults.User.localVersion
            
            AppGroupContainer.migrateIfNeeded()
            TaskDatabase.reloadCurrent()
            UserDatabase.reloadCurrent()
            
            if localVersion < 4 {
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob(request: .allAssets))
            }
            if localVersion < 18 {
                AppGroupUserDefaults.User.hasRecoverMedia = true
            }
            if localVersion < 25 {
                EdDSAMigration.migrate()
            }
            if localVersion < 26 {
                AppGroupUserDefaults.User.isCircleSynchronized = true
            }
            if localVersion < 27 {
                Logger.migrate()
            }
            if localVersion < 28 {
                let lottieCacheURL = AppGroupContainer.documentsUrl
                    .appendingPathComponent("Sticker")
                    .appendingPathComponent("Lottie")
                try? FileManager.default.removeItem(at: lottieCacheURL)
            }
            if localVersion < 30 {
                ConcurrentJobQueue.shared.addJob(job: RefreshAlbumJob())
            }
            if localVersion < 31 {
                if let id = Keychain.shared.removeDeviceID() {
                    AppGroupKeychain.deviceID = id
                }
            }
            if localVersion < 32 {
                AppGroupUserDefaults.Wallet.allTransactionsOffset = nil
                AppGroupUserDefaults.Wallet.assetTransactionsOffset = [:]
                AppGroupUserDefaults.Wallet.opponentTransactionsOffset = [:]
            }
            if localVersion < 33 {
                AppGroupUserDefaults.Wallet.hiddenAssetIds = [:]
            }
            
            AppGroupUserDefaults.User.needsRebuildDatabase = false
            AppGroupUserDefaults.User.localVersion = AppGroupUserDefaults.User.version
            
            let time = Date().timeIntervalSince(startTime)
            if time < 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + (2 - time), execute: {
                    self?.dismiss()
                })
            } else {
                DispatchQueue.main.async {
                    self?.dismiss()
                }
            }
        }
    }
    
    private func dismiss() {
        AppDelegate.current.mainWindow.rootViewController = makeInitialViewController(isUsernameJustInitialized: isUsernameJustInitialized)
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        upgrade()
    }
    
}
