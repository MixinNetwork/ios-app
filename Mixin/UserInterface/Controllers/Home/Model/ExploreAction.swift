import UIKit
import MixinServices

enum ExploreAction {
    
    case buy
    case swap
    case membership
    case referral
    case linkDesktop
    case customerService
    case editFavoriteApps
    
    var trayImage: UIImage? {
        switch self {
        case .buy, .swap, .membership, .referral, .linkDesktop, .customerService:
            R.image.explore.action_tray()
        case .editFavoriteApps:
            R.image.explore.edit_favorite_app()
        }
    }
    
    var iconImage: UIImage? {
        switch self {
        case .buy:
            R.image.explore.buy()
        case .swap:
            R.image.explore.swap()
        case .membership:
            R.image.explore.membership()
        case .referral:
            R.image.explore.referral()
        case .linkDesktop:
            if AppGroupUserDefaults.Account.isDesktopLoggedIn {
                R.image.explore.desktop_logged_in()
            } else {
                R.image.explore.link_desktop()
            }
        case .customerService:
            R.image.explore.customer_service()
        case .editFavoriteApps:
            nil
        }
    }
    
    var title: String {
        switch self {
        case .buy:
            R.string.localizable.buy()
        case .swap:
            R.string.localizable.swap()
        case .membership:
            R.string.localizable.mixin_one()
        case .referral:
            R.string.localizable.referral()
        case .linkDesktop:
            R.string.localizable.link_desktop()
        case .customerService:
            R.string.localizable.contact_support()
        case .editFavoriteApps:
            R.string.localizable.my_favorite_bots()
        }
    }
    
    var subtitle: String {
        switch self {
        case .buy:
            R.string.localizable.buy_crypto_with_cash()
        case .swap:
            R.string.localizable.trade_native_tokens()
        case .membership:
            R.string.localizable.mixin_one_desc()
        case .referral:
            R.string.localizable.referral_description()
        case .linkDesktop:
            if AppGroupUserDefaults.Account.isDesktopLoggedIn {
                R.string.localizable.logined()
            } else {
                R.string.localizable.link_desktop_description()
            }
        case .customerService:
            R.string.localizable.leave_message_to_team_mixin()
        case .editFavoriteApps:
            R.string.localizable.add_or_remove_favorite_bots()
        }
    }
    
}
