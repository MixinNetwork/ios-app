import Foundation
import MixinServices

enum PopupTip {
    
    struct RecoveryContext {
        
        enum Intent {
            case homePageInspection
            case logoutConfirmation
            case assetChangingConfirmation(onCancel: () -> Void)
        }
        
        let intent: Intent
        let enabledOptions: [AccountRecoveryOption]
        
    }
    
    enum AddMobileNumberIntent {
        case buyToken
        case setRecoveryContact
    }
    
    case appUpdate
    case recovery(RecoveryContext)
    case notification
    case verifyMobileNumber
    case appRating
    case importPrivateKey(Web3Wallet)
    case importMnemonics(Web3Wallet)
    case addMobileNumber(AddMobileNumberIntent)
    
    private var detectInterval: TimeInterval {
        switch self {
        case .appUpdate:
                .day
        case .recovery:
            7 * .day
        case .notification:
            2 * .day
        case .verifyMobileNumber:
            7 * .day
        case .appRating:
            2 * .week
        case .importPrivateKey, .importMnemonics, .addMobileNumber:
                .greatestFiniteMagnitude
        }
    }
    
}

extension PopupTip {
    
    static func inspect() async -> PopupTip? {
        guard let account = LoginManager.shared.account else {
            return nil
        }
        
        if userDismissalOutdates(tip: .appUpdate, dismissalDate: AppGroupUserDefaults.appUpdateTipDismissalDate),
           let latestVersion = account.system?.messenger.version,
           let currentVersion = Bundle.main.shortVersion,
           currentVersion < latestVersion
        {
            return .appUpdate
        }
        
        let enabledOptions = AccountRecoveryOption.enabledOptions(account: account)
        let context = RecoveryContext(intent: .homePageInspection, enabledOptions: enabledOptions)
        if enabledOptions.count < 2,
           userDismissalOutdates(tip: .recovery(context), dismissalDate: AppGroupUserDefaults.User.recoveryKitTipDismissalDate)
        {
            return .recovery(context)
        }
        
        if userDismissalOutdates(tip: .notification, dismissalDate: AppGroupUserDefaults.notificationTipDismissalDate),
           await !NotificationManager.shared.getAuthorized()
        {
            return .notification
        }
        
        if AppGroupUserDefaults.User.hasPerformedTransfer,
           userDismissalOutdates(tip: .appRating, dismissalDate: AppGroupUserDefaults.appRatingRequestDate),
           let firstLaunchDate = AppGroupUserDefaults.firstLaunchDate,
           -firstLaunchDate.timeIntervalSinceNow > 7 * .day
        {
            return .appRating
        }
        
        if !account.isAnonymous,
           let number = account.phone,
           !number.isEmpty,
           !account.isPhoneVerificationValid,
           userDismissalOutdates(tip: .verifyMobileNumber, dismissalDate: AppGroupUserDefaults.User.verifyPhoneTipDismissalDate)
        {
            return .verifyMobileNumber
        }
        
        return nil
    }
    
    static func userDismissalOutdates(tip: PopupTip, dismissalDate: Date?) -> Bool {
        if let date = dismissalDate {
            -date.timeIntervalSinceNow > tip.detectInterval
        } else {
            true
        }
    }
    
}
