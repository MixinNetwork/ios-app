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
    
    static func getCompleteScopeInfo(authInfo: AuthorizationResponse) -> ([(scope: Scope, name: String, desc: String)], [Scope.RawValue]) {
        guard let account = LoginManager.shared.account else {
            return ([], [Scope.PROFILE.rawValue])
        }
        var result = [(scope: Scope, name: String, desc: String)]()
        var scopes = [Scope.PROFILE.rawValue]
        result.append((.PROFILE, R.string.localizable.public_profile(), R.string.localizable.auth_profile_content(account.full_name, account.identity_number)))

        if authInfo.scopes.contains(Scope.PHONE.rawValue) {
            result.append((.PHONE, R.string.localizable.phone_Number(), account.phone))
            scopes.append(Scope.PHONE.rawValue)
        }
        if authInfo.scopes.contains(Scope.MESSAGES_REPRESENT.rawValue) {
            result.append((.MESSAGES_REPRESENT, R.string.localizable.represent_Messages(), R.string.localizable.auth_messages_represent_description()))
            scopes.append(Scope.MESSAGES_REPRESENT.rawValue)
        }
        if authInfo.scopes.contains(Scope.CONTACTS_READ.rawValue) {
            result.append((.CONTACTS_READ, R.string.localizable.read_Contacts(), R.string.localizable.access_your_contacts_list()))
            scopes.append(Scope.CONTACTS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.ASSETS.rawValue) {
            result.append((.ASSETS, R.string.localizable.read_Assets(), getAssetsBalanceText()))
            scopes.append(Scope.ASSETS.rawValue)
        }
        if authInfo.scopes.contains(Scope.SNAPSHOTS_READ.rawValue) {
            result.append((.SNAPSHOTS_READ, R.string.localizable.read_Snapshots(), R.string.localizable.access_your_snapshots()))
            scopes.append(Scope.SNAPSHOTS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.APPS_READ.rawValue) {
            result.append((.APPS_READ, R.string.localizable.read_Apps(), R.string.localizable.access_your_apps_list()))
            scopes.append(Scope.APPS_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.APPS_WRITE.rawValue) {
            result.append((.APPS_WRITE, R.string.localizable.manage_Apps(), R.string.localizable.manage_all_your_apps()))
            scopes.append(Scope.APPS_WRITE.rawValue)
        }
        if authInfo.scopes.contains(Scope.CIRCLES_READ.rawValue) {
            result.append((.CIRCLES_READ, R.string.localizable.read_Circles(), R.string.localizable.access_your_circle_list()))
            scopes.append(Scope.CIRCLES_READ.rawValue)
        }
        if authInfo.scopes.contains(Scope.CIRCLES_WRITE.rawValue) {
            result.append((.CIRCLES_WRITE, R.string.localizable.write_Circles(), R.string.localizable.manage_all_your_circles()))
            scopes.append(Scope.CIRCLES_WRITE.rawValue)
        }
        if authInfo.scopes.contains(Scope.COLLECTIBLES_READ.rawValue) {
            result.append((.COLLECTIBLES_READ, R.string.localizable.read_Collectibles(), R.string.localizable.access_your_collectibles()))
            scopes.append(Scope.COLLECTIBLES_READ.rawValue)
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
            result = R.string.localizable.auth_assets_more(result)
        }
        return result
    }
}


