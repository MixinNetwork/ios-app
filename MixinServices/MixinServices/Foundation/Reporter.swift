import Foundation
import Sentry

open class Reporter {
    
    public enum Event: String {
        case signUpStart        = "sign_up_start"
        case signUpFullname     = "sign_up_fullname"
        case signUpSetPIN       = "sign_up_set_pin"
        case loginStart         = "login_start"
        case loginRestore       = "login_restore"
        case loginVerifyPIN     = "login_verify_pin"
        case swapStart          = "swap_start"
        case swapCoinSwitch     = "swap_coin_switch"
        case swapQuote          = "swap_quote"
        case swapPreview        = "swap_preview"
        case swapSend           = "swap_send"
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
    
    open func registerUserInformation() {
        guard let account = LoginManager.shared.account else {
            return
        }
        SentrySDK.setUser(Sentry.User(userId: account.userID))
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
        let scope = Scope()
        scope.setTags(tags)
        SentrySDK.capture(message: event.rawValue, scope: scope)
    }
    
    public func report(event: Event, method: String) {
        report(event: event, tags: ["method": method])
    }
    
}
