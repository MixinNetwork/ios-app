import UIKit
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import AppsFlyerLib
import MixinServices

final class MainAppReporter: Reporter {
    
    override func registerUserInformation(account: Account) {
        super.registerUserInformation(account: account)
        let userIDHash = Reporter.userIDHash(userID: account.userID)
        Crashlytics.crashlytics().setUserID(userIDHash)
        Crashlytics.crashlytics().setCustomKeysAndValues([
            "FullName": account.fullName,
            "IdentityNumber": account.identityNumber
        ])
        Analytics.setUserID(userIDHash)
        AppsFlyerLib.shared().customerUserID = userIDHash
    }
    
    override func report(error: Error) {
        super.report(error: error)
        Crashlytics.crashlytics().record(error: error)
    }
    
    override func report(event: Event, tags: [String: String]? = nil) {
        switch event {
        case .signUpStart,
             .buyStart,
             .tradeSpotStart,
             .tradeSpotEnd,
             .tradePerpsOpenStart,
             .tradePerpsOpenEnd,
             .receiveStart,
             .receiveEnd,
             .sendStart,
             .sendEnd:
            AppsFlyerLib.shared().logEvent(event.rawValue, withValues: tags)
            AppsFlyerLib.shared().start()
        case .signUpAccountCreated:
            AppsFlyerLib.shared().logEvent(event.rawValue, withValues: tags)
            if let appInstanceID = Analytics.appInstanceID() {
                AppsFlyerLib.shared().customData = ["app_instance_id": appInstanceID]
            }
            AppsFlyerLib.shared().start()
        case .loginEnd:
            AppsFlyerLib.shared().logEvent(AFEventLogin, withValues: tags)
            AppsFlyerLib.shared().start()
        case .signUpEnd:
            AppsFlyerLib.shared().logEvent(AFEventCompleteRegistration, withValues: tags)
            AppsFlyerLib.shared().start()
        default:
            break
        }
        report(eventName: event.rawValue, tags: tags)
    }
    
    override func report(eventName: String, tags: [String : String]? = nil) {
        Analytics.logEvent(eventName, parameters: tags)
    }
    
    override func updateUserProperties(_ properties: UserProperty, account: Account? = nil) {
        super.updateUserProperties(properties, account: account)
        guard let account = account ?? LoginManager.shared.account else {
            return
        }
        if properties.contains(.emergencyContact) {
            let value = "\(account.hasEmergencyContact)"
            Analytics.setUserProperty(value, forName: "has_recovery_contact")
        }
        if properties.contains(.membership) {
            let value = account.membership?.unexpiredPlan?.rawValue ?? "none"
            Analytics.setUserProperty(value, forName: "membership")
        }
        if properties.contains(.notificationAuthorization) {
            Task {
                let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                let value = switch status {
                case .authorized, .provisional, .ephemeral:
                    "authorized"
                case .denied:
                    "denied"
                case .notDetermined:
                    "none"
                @unknown default:
                    "\(status.rawValue)"
                }
                Analytics.setUserProperty(value, forName: "notification_auth_status")
            }
        }
        if properties.contains(.assetLevel) {
            DispatchQueue.global().async {
                let sum = TokenDAO.shared.usdBalanceSum(includesHiddenTokens: true)
                Analytics.setUserProperty(sum.reportingAssetLevel, forName: "asset_level")
            }
        }
    }
    
    override func updateUserProperty(key: String, value: String) {
        super.updateUserProperty(key: key, value: value)
        Analytics.setUserProperty(value, forName: key)
    }
    
}
