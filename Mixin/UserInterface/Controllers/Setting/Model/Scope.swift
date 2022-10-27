import Foundation
import MixinServices

enum Scope: String {
    
    case PROFILE = "PROFILE:READ"
    case PHONE = "PHONE:READ"
    case ASSETS = "ASSETS:READ"
    case APPS_READ = "APPS:READ"
    case APPS_WRITE = "APPS:WRITE"
    case CONTACTS_READ = "CONTACTS:READ"
    case MESSAGES_REPRESENT = "MESSAGES:REPRESENT"
    case SNAPSHOTS_READ = "SNAPSHOTS:READ"
    case CIRCLES_READ = "CIRCLES:READ"
    case CIRCLES_WRITE = "CIRCLES:WRITE"
    case COLLECTIBLES_READ = "COLLECTIBLES:READ"
    
    struct GroupInfo: Equatable {
        let icon: UIImage
        let title: String
        var items: [ItemInfo]
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.title == rhs.title
        }
    }
    
    struct ItemInfo: Equatable {
        var isSelected: Bool = true
        let title: String
        let desc: String
        let scope: String
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.scope == rhs.scope
        }
    }
    
    static func getCompleteScopeInfos(authInfo: AuthorizationResponse) -> [GroupInfo] {
        var bots = [ItemInfo]()
        var wallet = [ItemInfo]()
        var circles = [ItemInfo]()
        var other = [ItemInfo]()
                
        if authInfo.scopes.contains(Scope.ASSETS.rawValue) {
            wallet.append(ItemInfo(title: R.string.localizable.read_your_assets(),
                                   desc: R.string.localizable.allow_bot_access_asset(),
                                   scope: Scope.ASSETS.rawValue))
        }
        if authInfo.scopes.contains(Scope.SNAPSHOTS_READ.rawValue) {
            wallet.append(ItemInfo(title: R.string.localizable.read_your_snapshots(),
                                   desc: R.string.localizable.allow_bot_access_snapshots(),
                                   scope: Scope.SNAPSHOTS_READ.rawValue))
        }
        if authInfo.scopes.contains(Scope.COLLECTIBLES_READ.rawValue) {
            wallet.append(ItemInfo(title: R.string.localizable.read_your_nfts(),
                                   desc: R.string.localizable.allow_bot_access_nfts(),
                                   scope: Scope.COLLECTIBLES_READ.rawValue))
        }
        
        if authInfo.scopes.contains(Scope.APPS_READ.rawValue) {
            bots.append(ItemInfo(title: R.string.localizable.read_your_apps(),
                                 desc: R.string.localizable.allow_bot_access_bots(),
                                 scope: Scope.APPS_READ.rawValue))
        }
        if authInfo.scopes.contains(Scope.APPS_WRITE.rawValue) {
            bots.append(ItemInfo(title: R.string.localizable.manager_your_apps(),
                                 desc: R.string.localizable.allow_bot_manager_bots(),
                                 scope: Scope.APPS_WRITE.rawValue))
        }
        
        if authInfo.scopes.contains(Scope.CIRCLES_READ.rawValue) {
            circles.append(ItemInfo(title: R.string.localizable.read_your_circles(),
                                    desc: R.string.localizable.allow_bot_access_circles(),
                                    scope: Scope.CIRCLES_READ.rawValue))
        }
        if authInfo.scopes.contains(Scope.CIRCLES_WRITE.rawValue) {
            circles.append(ItemInfo(title: R.string.localizable.read_your_circles(),
                                    desc: R.string.localizable.allow_bot_manager_circles(),
                                    scope: Scope.CIRCLES_WRITE.rawValue))
        }
        
        if authInfo.scopes.contains(Scope.PROFILE.rawValue) {
            other.append(ItemInfo(title: R.string.localizable.read_your_public_profile(),
                                  desc: R.string.localizable.allow_bot_access_profile(),
                                  scope: Scope.PROFILE.rawValue))
        }
        if authInfo.scopes.contains(Scope.PHONE.rawValue) {
            other.append(ItemInfo(title: R.string.localizable.read_your_phone_number(),
                                  desc: R.string.localizable.allow_bot_access_number(),
                                  scope: Scope.PHONE.rawValue))
        }
        if authInfo.scopes.contains(Scope.CONTACTS_READ.rawValue) {
            other.append(ItemInfo(title: R.string.localizable.read_your_contacts(),
                                  desc: R.string.localizable.allow_bot_access_contact(),
                                  scope: Scope.CONTACTS_READ.rawValue))
        }
        if authInfo.scopes.contains(Scope.MESSAGES_REPRESENT.rawValue) {
            other.append(ItemInfo(title: R.string.localizable.represent_send_messages(),
                                  desc: R.string.localizable.allow_bot_send_messages(),
                                  scope: Scope.MESSAGES_REPRESENT.rawValue))
        }
        
        var results = [GroupInfo]()
        if !circles.isEmpty {
            results.append(GroupInfo(icon: R.image.web.ic_authorization_circle()!, title: R.string.localizable.circles(), items: circles))
        }
        if !bots.isEmpty {
            results.append(GroupInfo(icon: R.image.web.ic_authorization_bot()!, title: R.string.localizable.bots(), items: bots))
        }
        if !wallet.isEmpty {
            results.append(GroupInfo(icon: R.image.web.ic_authorization_wallet()!, title: R.string.localizable.wallet(), items: wallet))
        }
        if !other.isEmpty {
            results.append(GroupInfo(icon: R.image.web.ic_authorization_guard()!, title: R.string.localizable.other(), items: other))
        }
        return results
    }
    
}
