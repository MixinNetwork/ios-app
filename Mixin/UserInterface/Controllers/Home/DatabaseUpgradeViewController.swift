import UIKit
import MixinServices

class DatabaseUpgradeViewController: UIViewController {
    
    class var needsUpgrade: Bool {
        !AppGroupUserDefaults.isDocumentsMigrated
            || AppGroupUserDefaults.User.needsUpgradeInMainApp
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
            TaskDatabase.reloadCurrent()
            
            UserDatabase.reloadCurrent()
            if !AppGroupUserDefaults.Database.isSentSenderKeyCleared {
                UserDatabase.current.clearSentSenderKey()
                AppGroupUserDefaults.Database.isSentSenderKeyCleared = true
            }
            
            if localVersion < 4 {
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
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
        AppDelegate.current.mainWindow.rootViewController = makeInitialViewController()
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        upgrade()
    }
    
}
