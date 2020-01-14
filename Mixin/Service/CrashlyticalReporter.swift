import UIKit
import FirebaseCore
import FirebaseAnalytics
import Crashlytics
import MixinServices

class CrashlyticalReporter: Reporter {
    
    required init() {
        super.init()
        FirebaseApp.configure()
    }
    
    override func registerUserInformation() {
        super.registerUserInformation()
        if let account = LoginManager.shared.account {
            Crashlytics.sharedInstance().setUserIdentifier(account.user_id)
            Crashlytics.sharedInstance().setUserName(account.full_name)
            Crashlytics.sharedInstance().setUserEmail(account.identity_number)
            Crashlytics.sharedInstance().setObjectValue(Bundle.main.bundleIdentifier ?? "", forKey: "Package")
        }
    }
    
    override func report(event: Reporter.Event, userInfo: Reporter.UserInfo? = nil) {
        super.report(event: event, userInfo: userInfo)
        Analytics.logEvent(event.name, parameters: userInfo)
    }
    
    override func report(error: Error) {
        super.report(error: error)
        Crashlytics.sharedInstance().recordError(error)
    }
    
    override func reportErrorToFirebase(_ error: Error) {
        super.reportErrorToFirebase(error)
        Crashlytics.sharedInstance().recordError(error)
    }
    
}
