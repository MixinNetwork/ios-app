import UIKit
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import MixinServices

class CrashlyticalReporter: Reporter {

    override func registerUserInformation() {
        super.registerUserInformation()
        if let account = LoginManager.shared.account {
            Crashlytics.crashlytics().setUserID(account.userID)
            Crashlytics.crashlytics().setCustomValue(account.fullName, forKey: "FullName")
            Crashlytics.crashlytics().setCustomValue(account.identityNumber, forKey: "IdentityNumber")
        }
    }
    
    override func report(event: Reporter.Event, userInfo: Reporter.UserInfo? = nil) {
        super.report(event: event, userInfo: userInfo)
        Analytics.logEvent(event.name, parameters: userInfo)
    }
    
    override func report(error: Error, userInfo: UserInfo? = nil) {
        super.report(error: error, userInfo: userInfo)
        Crashlytics.crashlytics().record(error: error)
    }
    
}
