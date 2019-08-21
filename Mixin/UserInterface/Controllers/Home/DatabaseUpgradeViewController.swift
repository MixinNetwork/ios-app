import UIKit
import WCDBSwift

class DatabaseUpgradeViewController: UIViewController {

    class func instance() -> DatabaseUpgradeViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "database") as! DatabaseUpgradeViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        FileManager.default.writeLog(log: "DatabaseUpgradeViewController...")
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            let currentVersion = DatabaseUserDefault.shared.databaseVersion
            if currentVersion < 2 {
                TaskDatabase.shared.initDatabase()
                MixinDatabase.shared.initDatabase()

                DatabaseUserDefault.shared.initiatedFTS = false
                ConcurrentJobQueue.shared.addJob(job: FTSJob())
            }

            DatabaseUserDefault.shared.databaseVersion = DatabaseUserDefault.shared.currentDatabaseVersion
            
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
        AppDelegate.current.window?.rootViewController = makeInitialViewController()
    }

}
