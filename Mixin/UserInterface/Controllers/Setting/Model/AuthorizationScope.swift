import Foundation
import MixinServices

enum AuthorizationScope: String {
    
    enum Group: CaseIterable {
        
        case profile
        case wallet
        case bot
        case message
        case circle
        
        var icon: UIImage {
            switch self {
            case .profile:
                return R.image.web.ic_authorization_profile()!
            case .wallet:
                return R.image.web.ic_authorization_wallet()!
            case .bot:
                return R.image.web.ic_authorization_bot()!
            case .message:
                return R.image.web.ic_authorization_message()!
            case .circle:
                return R.image.web.ic_authorization_circle()!
            }
        }
        
        var title: String {
            switch self {
            case .profile:
                return R.string.localizable.profile()
            case .wallet:
                return R.string.localizable.wallet()
            case .bot:
                return R.string.localizable.bots()
            case .message:
                return R.string.localizable.messages()
            case .circle:
                return R.string.localizable.circles()
            }
        }
        
        var scopes: [AuthorizationScope] {
            switch self {
            case .profile:
                return [.readProfile, .readPhone, .readContacts]
            case .wallet:
                return [.readAssets, .readSnapshots, .readCollectibles]
            case .bot:
                return [.readApps, .writeApps]
            case .message:
                return [.representMessages]
            case .circle:
                return [.readCircles, .writeCircles]
            }
        }
        
    }
    
    case readProfile = "PROFILE:READ"
    case readPhone = "PHONE:READ"
    case readAssets = "ASSETS:READ"
    case readApps = "APPS:READ"
    case writeApps = "APPS:WRITE"
    case readContacts = "CONTACTS:READ"
    case representMessages = "MESSAGES:REPRESENT"
    case readSnapshots = "SNAPSHOTS:READ"
    case readCircles = "CIRCLES:READ"
    case writeCircles = "CIRCLES:WRITE"
    case readCollectibles = "COLLECTIBLES:READ"
    
    var title: String {
        switch self {
        case .readProfile:
            return R.string.localizable.read_your_public_profile()
        case .readPhone:
            return R.string.localizable.read_your_phone_number()
        case .readAssets:
            return R.string.localizable.read_your_assets()
        case .readApps:
            return R.string.localizable.read_your_apps()
        case .writeApps:
            return R.string.localizable.manage_your_apps()
        case .readContacts:
            return R.string.localizable.read_your_contacts()
        case .representMessages:
            return R.string.localizable.represent_send_messages()
        case .readSnapshots:
            return R.string.localizable.read_your_snapshots()
        case .readCircles:
            return R.string.localizable.read_your_circles()
        case .writeCircles:
            return R.string.localizable.manage_your_circles()
        case .readCollectibles:
            return R.string.localizable.read_your_nfts()
        }
    }
    
    var description: String {
        switch self {
        case .readProfile:
            return R.string.localizable.allow_bot_access_profile()
        case .readPhone:
            return R.string.localizable.allow_bot_access_number()
        case .readAssets:
            return R.string.localizable.allow_bot_access_asset()
        case .readApps:
            return R.string.localizable.allow_bot_access_bots()
        case .writeApps:
            return R.string.localizable.allow_bot_manage_bots()
        case .readContacts:
            return R.string.localizable.allow_bot_access_contact()
        case .representMessages:
            return R.string.localizable.allow_bot_send_messages()
        case .readSnapshots:
            return R.string.localizable.allow_bot_access_snapshots()
        case .readCircles:
            return R.string.localizable.allow_bot_access_circles()
        case .writeCircles:
            return R.string.localizable.allow_bot_manage_circles()
        case .readCollectibles:
            return R.string.localizable.allow_bot_access_nfts()
        }
    }
    
}
