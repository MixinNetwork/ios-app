import Foundation

public final class BadgeManager {
    
    public enum Identifier: String, CaseIterable {
        case walletSwitch = "wallet_switch"
        case addWallet = "add_wallet"
        case buy = "buying"
        case trade = "swap"
        case tradeOrder = "swap_order"
        case membership = "membership"
        case referral = "referral"
        case safeVault = "safe_vault"
        case advancedTrade = "advanced_trade"
    }
    
    public static let shared = BadgeManager()
    public static let viewedNotification = Notification.Name("one.mixin.messenger.BadgeManager.Viewed")
    public static let identifierUserInfoKey = "i"
    
    private var hasViewed: [Identifier: Bool] = [:]
    
    public func hasViewed(identifier: Identifier) -> Bool {
        assert(Thread.isMainThread)
        if let value = hasViewed[identifier] {
            return value
        } else {
            let key = "has_viewed_" + identifier.rawValue
            let value: Bool = PropertiesDAO.shared.unsafeValue(forKey: key) ?? false
            hasViewed[identifier] = value
            return value
        }
    }
    
    public func setHasViewed(identifier: Identifier) {
        assert(Thread.isMainThread)
        guard !(hasViewed[identifier] ?? false) else {
            return
        }
        hasViewed[identifier] = true
        DispatchQueue.global().async {
            let key = "has_viewed_" + identifier.rawValue
            PropertiesDAO.shared.setWithoutNotification(true, forKey: key)
        }
        NotificationCenter.default.post(
            name: Self.viewedNotification,
            object: self,
            userInfo: [Self.identifierUserInfoKey: identifier]
        )
    }
    
    public func resetAll() {
        DispatchQueue.global().async {
            for identifier in Identifier.allCases {
                let key = "has_viewed_" + identifier.rawValue
                PropertiesDAO.shared.removeValueWithoutNotification(forKey: key)
            }
        }
    }
    
    func prepareForAccountChange() {
        assert(Thread.isMainThread)
        hasViewed = [:]
    }
    
}
