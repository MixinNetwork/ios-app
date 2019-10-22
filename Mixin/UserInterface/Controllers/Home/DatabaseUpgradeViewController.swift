import UIKit
import WCDBSwift

class DatabaseUpgradeViewController: UIViewController {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    class func instance() -> DatabaseUpgradeViewController {
        return Storyboard.home.instantiateViewController(withIdentifier: "database") as! DatabaseUpgradeViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.set(font: .systemFont(ofSize: 17, weight: .semibold), adjustForContentSize: true)
        FileManager.default.writeLog(log: "DatabaseUpgradeViewController...")
        let startTime = Date()
        DispatchQueue.global().async { [weak self] in
            let currentVersion = DatabaseUserDefault.shared.databaseVersion

            TaskDatabase.shared.initDatabase()
            MixinDatabase.shared.initDatabase(clearSentSenderKey: DatabaseUserDefault.shared.clearSentSenderKey)
            DatabaseUserDefault.shared.clearSentSenderKey = false

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
                ConcurrentJobQueue.shared.addJob(job: RefreshAssetsJob())
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
