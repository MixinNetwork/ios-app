import UIKit
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import MixinServices

class CrashlyticalReporter: Reporter {

    override func registerUserInformation() {
        super.registerUserInformation()
        if let account = LoginManager.shared.account {
            Crashlytics.crashlytics().setUserID(account.user_id)
            Crashlytics.crashlytics().setCustomValue(account.full_name, forKey: "FullName")
            Crashlytics.crashlytics().setCustomValue(account.identity_number, forKey: "IdentityNumber")
        }
    }
    
    override func report(event: Reporter.Event, userInfo: Reporter.UserInfo? = nil) {
        super.report(event: event, userInfo: userInfo)
        Analytics.logEvent(event.name, parameters: userInfo)
    }
    
    override func report(error: Error) {
        super.report(error: error)
        Crashlytics.crashlytics().record(error: error)
    }
    
}
