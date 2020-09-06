import UIKit
import WCDBSwift
import MixinServices

class DatabaseUpgradeViewController: UIViewController {
    
    class var needsUpgrade: Bool {
        !AppGroupUserDefaults.isDocumentsMigrated
            || AppGroupUserDefaults.User.needsUpgradeInMainApp
            || EdDSAMigration.needsMigration
    }
    
    class func instance() -> DatabaseUpgradeViewController {
        return R.storyboard.home.database()!
    }
    
    private var isUpgrading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        upgrade()
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func upgrade() {
        Logger.write(log: "DatabaseUpgradeViewController...applicationState:\(UIApplication.shared.applicationStateString)")
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
            TaskDatabase.shared.initDatabase()
            
            let shouldClearSentSenderKey = !AppGroupUserDefaults.Database.isSentSenderKeyCleared
            MixinDatabase.shared.initDatabase(clearSentSenderKey: shouldClearSentSenderKey)
            AppGroupUserDefaults.Database.isSentSenderKeyCleared = true
            
            if localVersion < 4 {
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
            }
            if localVersion < 18 {
                AppGroupUserDefaults.User.hasRecoverMedia = true
            }
            
            AppGroupUserDefaults.User.needsRebuildDatabase = false
            AppGroupUserDefaults.User.localVersion = AppGroupUserDefaults.User.version
            
            if EdDSAMigration.needsMigration {
                EdDSAMigration.migrate()
            }
            
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
        AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        upgrade()
    }
    
}
