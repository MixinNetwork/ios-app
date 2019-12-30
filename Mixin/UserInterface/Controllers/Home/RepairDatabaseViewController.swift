import UIKit
import WCDBSwift

class RepairDatabaseViewController: UIViewController {

    class func instance() -> RepairDatabaseViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "repair") as! RepairDatabaseViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        FileManager.default.writeLog(log: "RepairDatabaseViewController...")
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            do {
                try MixinDatabase.shared.recover()
                DatabaseUserDefault.shared.hasRecoverMixinDatabaseVersion = false
            } catch let err as WCDBSwift.Error {
                print(err)
                UIApplication.traceWCDBError(err)
            } catch {
                print(error)
                UIApplication.traceError(error)
            }
            let time = Date().timeIntervalSince(startTime)
            if time < 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + (2 - time), execute: {
                    self?.dismiss()
                })
            } else {
                self?.dismiss()
            }
        }
    }

    private func dismiss() {
        AppDelegate.current.window?.rootViewController = makeInitialViewController()
    }

}
