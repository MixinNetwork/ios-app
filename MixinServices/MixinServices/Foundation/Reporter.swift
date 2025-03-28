import Foundation
import Sentry

open class Reporter {
    
    public enum Event: String {
        case signUpStart        = "sign_up_start"
        case signUpFullname     = "sign_up_fullname"
        case signUpRecaptcha    = "sign_up_recaptcha"
        case signUpSmsVerify    = "sign_up_sms_verify"
        case signUpSignalInit   = "sign_up_signal_init"
        case signUpPINSet       = "sign_up_pin_set"
        case signUpEnd          = "sign_up_end"
        
        case loginStart         = "login_start"
        case loginRestore       = "login_restore"
        case loginVerifyPIN     = "login_verify_pin"
        case loginRecaptcha     = "login_recaptcha"
        case loginSignalInit    = "login_signal_init"
        case loginEnd           = "login_end"
        
        case tradeStart         = "trade_start"
        case tradeTokenSelect   = "trade_token_select"
        case tradeQuote         = "trade_quote"
        case tradePreview       = "trade_preview"
        case tradeEnd           = "trade_end"
        case tradeTransactions  = "trade_transactions"
        case tradeDetail        = "trade_detail"
        
        case homeTabSwitch        = "home_tab_switch"
        case moreTabSwitch        = "more_tab_switch"
        
        case customerServiceDialog = "customer_service_dialog"
        
        case errorSessionVerifications = "error_session_verifications"
    }
    
    public struct UserProperty: OptionSet {
        
        public static let all = UserProperty(rawValue: .max)
        
        public static let emergencyContact = UserProperty(rawValue: 1 << 0)
        public static let membership = UserProperty(rawValue: 1 << 1)
        public static let notificationAuthorization = UserProperty(rawValue: 1 << 2)
        public static let assetLevel = UserProperty(rawValue: 1 << 3)
        
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
    }
    
    public typealias UserInfo = [String: Any]
    
    public required init() {
        
    }
    
    open func configure() {
        guard
            let path = Bundle.main.path(forResource: "Mixin-Keys", ofType: "plist"),
            let keys = NSDictionary(contentsOfFile: path) as? [String: Any],
            let sentryKey = keys["Sentry"] as? String
        else {
            return
        }
        
        SentrySDK.start { options in
            options.dsn = sentryKey
            options.enablePerformanceV2 = true
#if DEBUG
            options.tracesSampleRate = 1.0
#else
            options.tracesSampleRate = 0.1
#endif
        }
    }
    
    open func registerUserInformation(account: Account) {
        let user = Sentry.User(userId: account.userID)
        SentrySDK.setUser(user)
    }
    
    open func report(error: MixinAPIError) {
        SentrySDK.capture(error: error)
    }
    
    open func report(error: Error, userInfo: UserInfo? = nil) {
        if let info = userInfo {
            let event = Sentry.Event(level: .error)
            event.extra = userInfo
            SentrySDK.capture(event: event)
        } else {
            SentrySDK.capture(error: error)
        }
    }
    
    open func report(event: Event, tags: [String: String]? = nil) {
        // Reduce Sentry usage
    }
    
    open func updateUserProperties(_ properties: UserProperty, account: Account? = nil) {
        
    }
    
}

extension Reporter {
    
    public func report(event: Event, method: String) {
        report(event: event, tags: ["method": method])
    }
    
}
