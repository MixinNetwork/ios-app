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
            let localVersion = AppGroupUserDefaults.User.localVersion

            TaskDatabase.shared.initDatabase()
            
            let shouldClearSentSenderKey = !AppGroupUserDefaults.Database.isSentSenderKeyCleared
            MixinDatabase.shared.initDatabase(clearSentSenderKey: shouldClearSentSenderKey)
            AppGroupUserDefaults.Database.isSentSenderKeyCleared = true

            if localVersion < 3 {
                if let currency = WalletUserDefault.shared.currencyCode, !currency.isEmpty {
                    AccountAPI.shared.preferences(preferenceRequest: UserPreferenceRequest.createRequest(fiat_currency: currency), completion: {  (result) in
                        if case let .success(account) = result {
                            AccountAPI.shared.updateAccount(account: account)
                            Currency.refreshCurrentCurrency()
                        }
                    })
                }
            }
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
