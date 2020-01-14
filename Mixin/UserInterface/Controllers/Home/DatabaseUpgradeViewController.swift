import UIKit
import WCDBSwift
import MixinServices

class DatabaseUpgradeViewController: UIViewController {
    
    class var needsUpgrade: Bool {
        !AppGroupUserDefaults.isDocumentsMigrated || AppGroupUserDefaults.User.needsUpgradeInMainApp
    }
    
    class func instance() -> DatabaseUpgradeViewController {
        return R.storyboard.home.database()!
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            let localVersion = AppGroupUserDefaults.User.localVersion
            
            AppGroupContainer.migrateIfNeeded()
            
            Logger.write(log: "DatabaseUpgradeViewController...")
            
            TaskDatabase.shared.initDatabase()
            
            let shouldClearSentSenderKey = !AppGroupUserDefaults.Database.isSentSenderKeyCleared
            MixinDatabase.shared.initDatabase(clearSentSenderKey: shouldClearSentSenderKey)
            AppGroupUserDefaults.Database.isSentSenderKeyCleared = true
            
            if localVersion < 4 {
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
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
        AppDelegate.current.window.rootViewController = makeInitialViewController()
    }

}
