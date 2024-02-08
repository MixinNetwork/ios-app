import UIKit
import MixinServices

enum ExploreAction {
    
    case camera
    case linkDesktop
    case customerService
    case editFavoriteApps
    
    var trayImage: UIImage? {
        switch self {
        case .camera, .linkDesktop, .customerService:
            R.image.explore.action_tray()
        case .editFavoriteApps:
            R.image.explore.edit_favorite_app()
        }
    }
    
    var iconImage: UIImage? {
        switch self {
        case .camera:
            R.image.explore.camera()
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
        case .camera:
            R.string.localizable.camera()
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
        case .camera:
            R.string.localizable.take_a_photo()
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
