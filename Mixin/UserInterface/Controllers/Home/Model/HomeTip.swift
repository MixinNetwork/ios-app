import Foundation
import MixinServices

enum HomeTip {
    
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

extension HomeTip {
    
    static func next() async -> HomeTip? {
        guard let account = LoginManager.shared.account else {
            return nil
        }
        
        lazy var walletUSDBalance = TokenDAO.shared.usdBalanceSum()
        
        if userDismissalOutdated(tip: .appUpdate, dismissalDate: AppGroupUserDefaults.appUpdateTipDismissalDate),
           let latestVersion = account.system?.messenger.version,
           let currentVersion = Bundle.main.shortVersion,
           currentVersion < latestVersion
        {
            return .appUpdate
        }
        
        if account.isAnonymous,
           !account.hasSaltExported,
           userDismissalOutdated(tip: .backupMnemonics, dismissalDate: AppGroupUserDefaults.User.backupMnemonicsTipDismissalDate)
        {
            return .backupMnemonics
        }
        
        if userDismissalOutdated(tip: .notification, dismissalDate: AppGroupUserDefaults.notificationTipDismissalDate),
           await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied,
           walletUSDBalance > 0
        {
            return .notification
        }
        
        if !account.hasEmergencyContact,
           userDismissalOutdated(tip: .recoveryContact, dismissalDate: AppGroupUserDefaults.User.recoveryContactTipDismissalDate),
           walletUSDBalance > 100
        {
            return .recoveryContact
        }
        
        if AppGroupUserDefaults.User.hasPerformedTransfer,
           userDismissalOutdated(tip: .appRating, dismissalDate: AppGroupUserDefaults.appRatingRequestDate),
           let firstLaunchDate = AppGroupUserDefaults.firstLaunchDate,
           -firstLaunchDate.timeIntervalSinceNow > 7 * .day
        {
            return .appRating
        }
        
        return nil
    }
    
    private static func userDismissalOutdated(tip: HomeTip, dismissalDate: Date?) -> Bool {
        if let date = dismissalDate {
            -date.timeIntervalSinceNow > tip.detectInterval
        } else {
            true
        }
    }
    
}
