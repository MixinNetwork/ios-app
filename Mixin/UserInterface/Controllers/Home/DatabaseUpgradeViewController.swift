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

            TaskDatabase.shared.initDatabase()
            MixinDatabase.shared.initDatabase()

            if currentVersion < 3 {
                if let currency = WalletUserDefault.shared.currencyCode, !currency.isEmpty {
                    AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest.createRequest(fiat_currency: currency), completion: {  (result) in
                        if case let .success(account) = result {
                            AccountAPI.shared.updateAccount(account: account)
                            Currency.refreshCurrentCurrency()
                        }
                    })
                }
            }
            if currentVersion < 4 {
                if AccountUserDefault.shared.hasRestoreFilesAndVideos {
                    AccountUserDefault.shared.hasRestoreMedia = true
                    AccountUserDefault.shared.hasRestoreFilesAndVideos = false
                }
            }

            DatabaseUserDefault.shared.forceUpgradeDatabase = false
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
        AppDelegate.current.window.rootViewController = makeInitialViewController()
    }

}
