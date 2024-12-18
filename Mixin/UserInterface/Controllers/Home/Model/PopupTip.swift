import Foundation
import MixinServices

enum PopupTip {
    
    case appUpdate
    case backupMnemonics
    case notification
    case recoveryContact
    case appRating
    
    private var detectInterval: TimeInterval {
        switch self {
        case .appUpdate:
                .day
        case .backupMnemonics:
                .day
        case .notification:
            2 * .day
        case .recoveryContact:
            7 * .day
        case .appRating:
            2 * .week
        }
    }
    
}

extension PopupTip {
    
    static func next() async -> PopupTip? {
        guard let account = LoginManager.shared.account else {
            return nil
        }
        
        lazy var walletUSDBalance = TokenDAO.shared.usdBalanceSum()
        
        if userDismissalOutdates(tip: .appUpdate, dismissalDate: AppGroupUserDefaults.appUpdateTipDismissalDate),
           let latestVersion = account.system?.messenger.version,
           let currentVersion = Bundle.main.shortVersion,
           currentVersion < latestVersion
        {
            return .appUpdate
        }
        
        if account.isAnonymous,
           !account.hasSaltExported,
           userDismissalOutdates(tip: .backupMnemonics, dismissalDate: AppGroupUserDefaults.User.backupMnemonicsTipDismissalDate)
        {
            return .backupMnemonics
        }
        
        if userDismissalOutdates(tip: .notification, dismissalDate: AppGroupUserDefaults.notificationTipDismissalDate),
           await !NotificationManager.shared.getAuthorized(),
           walletUSDBalance > 0
        {
            return .notification
        }
        
        if !account.hasEmergencyContact,
           userDismissalOutdates(tip: .recoveryContact, dismissalDate: AppGroupUserDefaults.User.recoveryContactTipDismissalDate),
           walletUSDBalance > 100
        {
            return .recoveryContact
        }
        
        if AppGroupUserDefaults.User.hasPerformedTransfer,
           userDismissalOutdates(tip: .appRating, dismissalDate: AppGroupUserDefaults.appRatingRequestDate),
           let firstLaunchDate = AppGroupUserDefaults.firstLaunchDate,
           -firstLaunchDate.timeIntervalSinceNow > 7 * .day
        {
            return .appRating
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
