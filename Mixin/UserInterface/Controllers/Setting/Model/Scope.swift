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
    
    static func getCompleteScopeInfo(authInfo: AuthorizationResponse) -> ([(scope: Scope, name: String, desc: String)], [Scope.RawValue]) {
        guard let account = LoginManager.shared.account else {
            return ([], [Scope.PROFILE.rawValue])
        }
        var result = [(scope: Scope, name: String, desc: String)]()
        var scopes = [Scope.PROFILE.rawValue]
        result.append((.PROFILE, Localized.AUTH_PERMISSION_PROFILE, Localized.AUTH_PROFILE_DESCRIPTION(fullName: account.full_name, phone: account.identity_number)))

        if authInfo.scopes.contains(Scope.PHONE.rawValue) {
            result.append((.PHONE, Localized.AUTH_PERMISSION_PHONE, account.phone))
            scopes.append(Scope.PHONE.rawValue)
        }
        if authInfo.scopes.contains(Scope.MESSAGES_REPRESENT.rawValue) {
            result.append((.MESSAGES_REPRESENT, R.string.localizable.auth_permission_messages_represent(), R.string.localizable.auth_permission_messages_represent_description()))
            scopes.append(Scope.MESSAGES_REPRESENT.rawValue)
        }
        if authInfo.scopes.contains(Scope.CONTACTS_READ.rawValue) {
            result.append((.CONTACTS_READ, Localized.AUTH_PERMISSION_CONTACTS_READ, Localized.AUTH_PERMISSION_CONTACTS_READ_DESCRIPTION))
            scopes.append(Scope.CONTACTS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.ASSETS.rawValue) {
            result.append((.ASSETS, Localized.AUTH_PERMISSION_ASSETS, getAssetsBalanceText()))
            scopes.append(Scope.ASSETS.rawValue)
        }
        if authInfo.scopes.contains(Scope.SNAPSHOTS_READ.rawValue) {
            result.append((.SNAPSHOTS_READ, R.string.localizable.auth_permission_snapshots_read(), R.string.localizable.auth_permission_snapshots_read_description()))
            scopes.append(Scope.SNAPSHOTS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.APPS_READ.rawValue) {
            result.append((.APPS_READ, Localized.AUTH_PERMISSION_APPS_READ, Localized.AUTH_PERMISSION_APPS_READ_DESCRIPTION))
            scopes.append(Scope.APPS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.APPS_WRITE.rawValue) {
            result.append((.APPS_WRITE, Localized.AUTH_PERMISSION_APPS_WRITE, Localized.AUTH_PERMISSION_APPS_WRITE_DESCRIPTION))
            scopes.append(Scope.APPS_WRITE.rawValue)
        }
        if authInfo.scopes.contains(Scope.CIRCLES_READ.rawValue) {
            result.append((.CIRCLES_READ, R.string.localizable.auth_permission_circles_read(), R.string.localizable.auth_permission_circles_read_description()))
            scopes.append(Scope.CIRCLES_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.CIRCLES_WRITE.rawValue) {
            result.append((.CIRCLES_WRITE, R.string.localizable.auth_permission_circles_write(), R.string.localizable.auth_permission_circles_write_description()))
            scopes.append(Scope.CIRCLES_WRITE.rawValue)
        }
        return (result, scopes)
    }
    
    private static func getAssetsBalanceText() -> String {
        let assets = AssetDAO.shared.getAssets()
        guard assets.count > 0 else {
            return "0"
        }
        var result = "\(assets[0].localizedBalance) \(assets[0].symbol)"
        if assets.count > 1 {
            result += ", \(assets[1].localizedBalance) \(assets[1].symbol)"
        }
        if assets.count > 2 {
            result += Localized.AUTH_ASSETS_MORE
        }
        return result
    }
}


