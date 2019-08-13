import UIKit
import WCDBSwift

class DatabaseUpgradeViewController: UIViewController {

    class func instance() -> SignalLoadingViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "database") as! SignalLoadingViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        FileManager.default.writeLog(log: "DatabaseUpgradeViewController...")
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            let currentVersion = DatabaseUserDefault.shared.databaseVersion
            if currentVersion < 1 {
                DatabaseUpgradeViewController.copyTableData(type: MessageHistory.self)
                DatabaseUpgradeViewController.copyTableData(type: Job.self)
                DatabaseUpgradeViewController.copyTableData(type: ResendMessage.self)
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

    private static func copyTableData<T: BaseCodable>(type: T.Type) {
        JobDatabase.shared.deleteAll(table: T.tableName)

        var datas = [T]()
        var offset = 0
        repeat {
            datas = MixinDatabase.shared.getCodables(offset: offset, limit: 1000)
            JobDatabase.shared.insert(objects: datas)
            offset += datas.count
        } while datas.count >= 1000
    }

}
