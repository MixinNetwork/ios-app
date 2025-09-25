import UIKit
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import MixinServices

final class MainAppReporter: Reporter {
    
    override func registerUserInformation(account: Account) {
        super.registerUserInformation(account: account)
        Crashlytics.crashlytics().setUserID(account.userID)
        Crashlytics.crashlytics().setCustomKeysAndValues([
            "FullName": account.fullName,
            "IdentityNumber": account.identityNumber
        ])
        Analytics.setUserID(account.userID)
    }
    
    override func report(error: Error) {
        super.report(error: error)
        Crashlytics.crashlytics().record(error: error)
    }
    
    override func report(event: Event, tags: [String: String]? = nil) {
        super.report(event: event, tags: tags)
        Analytics.logEvent(event.rawValue, parameters: tags)
    }
    
    override func updateUserProperties(_ properties: UserProperty, account: Account? = nil) {
        super.updateUserProperties(properties, account: account)
        guard let account = account ?? LoginManager.shared.account else {
            return
        }
        if properties.contains(.emergencyContact) {
            let value = "\(account.hasEmergencyContact)"
            Analytics.setUserProperty(value, forName: "has_emergency_contact")
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
                let sum = TokenDAO.shared.usdBalanceSum()
                let value = switch sum {
                case 0:
                    "v0"
                case ..<100:
                    "v1"
                case ..<1_000:
                    "v100"
                case ..<10_000:
                    "v1,000"
                case ..<100_000:
                    "v10,000"
                case ..<1_000_000:
                    "v100,000"
                case ..<10_000_000:
                    "v1,000,000"
                default:
                    "v10,000,000"
                }
                Analytics.setUserProperty(value, forName: "asset_level")
            }
        }
    }
    
}
