import Foundation
import Bugsnag

open class Reporter {
    
    public enum Event: String {
        case signUpStart        = "sign_up_start"
        case signUpFullname     = "sign_up_fullname"
        case signUpCAPTCHA      = "sign_up_captcha"
        case signUpSMSVerify    = "sign_up_sms_verify"
        case signUpSignalInit   = "sign_up_signal_init"
        case signUpPINSet       = "sign_up_pin_set"
        case signUpEnd          = "sign_up_end"
        
        case loginStart         = "login_start"
        case loginSMSVerify     = "login_sms_verify"
        case loginRestore       = "login_restore"
        case loginVerifyPIN     = "login_verify_pin"
        case loginCAPTCHA       = "login_captcha"
        case loginSignalInit    = "login_signal_init"
        case loginEnd           = "login_end"
        
        case tradeStart         = "trade_start"
        case tradeTokenSelect   = "trade_token_select"
        case tradeQuote         = "trade_quote"
        case tradePreview       = "trade_preview"
        case tradeEnd           = "trade_end"
        case tradeTransactions  = "trade_transactions"
        case tradeDetail        = "trade_detail"
        
        case assetDetail        = "asset_detail"
        case allTransactions    = "all_transactions"
        case transactionDetail  = "transaction_detail"
        
        case receiveStart       = "asset_receive_start"
        case receiveTokenSelect = "asset_receive_token_select"
        case receiveChainSelect = "asset_receive_chain_select"
        case receiveEnd         = "asset_receive_end"
        
        case sendStart          = "asset_send_start"
        case sendTokenSelect    = "asset_send_token_select"
        case sendRecipient      = "asset_send_recipient"
        case sendAmount         = "asset_send_amount"
        case sendPreview        = "asset_send_preview"
        case sendEnd            = "asset_send_end"
        
        case addAddressStart    = "address_book_add_start"
        case addAddressMemo     = "address_book_add_memo"
        case addAddressLabel    = "address_book_add_label"
        case addAddressPreview  = "address_book_add_preview"
        case addAddressEnd      = "address_book_add_end"
        
        case homeTabSwitch      = "home_tab_switch"
        case moreTabSwitch      = "more_tab_switch"
        
        case accountResumePIN     = "account_resume_pin"
        
        case customerServiceDialog       = "customer_service_dialog"
        case errorSessionVerifications   = "error_session_verifications"
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
            let keys = NSDictionary(contentsOfFile: path),
            let key = keys["Bugsnag"] as? String
        else {
            return
        }
        Bugsnag.start(withApiKey: key)
    }
    
    open func registerUserInformation(account: Account) {
        Bugsnag.setUser(account.userID, withEmail: "\(account.identityNumber)@mixin.id", andName: account.fullName)
    }
    
    open func report(error: Error) {
        Bugsnag.notifyError(error)
    }
    
    open func report(event: Event, tags: [String: String]? = nil) {
        // Reduce bug report usage
    }
    
    open func updateUserProperties(_ properties: UserProperty, account: Account? = nil) {
        
    }
    
}
