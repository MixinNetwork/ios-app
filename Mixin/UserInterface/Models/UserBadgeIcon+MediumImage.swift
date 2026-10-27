import UIKit
import SDWebImage
import MixinServices

extension UserBadgeIcon {
    
    static let mediumProsperityImage: SDAnimatedImage? = {
        let resource = R.file.user_membership_prosperityJson.url()!
        let data = try! Data(contentsOf: resource)
        let size = CGSize(width: 20, height: 20) * UIScreen.main.scale
        let image = SDAnimatedImage(
            data: data,
            scale: UIScreen.main.scale,
            options: [.decodeThumbnailPixelSize: size]
        )
        return image
    }()
    
    var mediumImage: UIImage? {
        switch self {
        case .membership(let plan):
            plan.mediumBadgeImage
        case .verification:
            R.image.ic_user_verified()
        case .bot:
            R.image.badge_app_medium()
        }
    }
    
}

extension User.Membership.Plan {
    
    var mediumBadgeImage: UIImage? {
        switch self {
        case .advance:
            R.image.membership_advance_medium()
        case .elite:
            R.image.membership_elite_medium()
        case .prosperity:
            UserBadgeIcon.mediumProsperityImage
        }
    }
    
}

extension User.Membership {
    
    var badgeImage: UIImage? {
        unexpiredPlan?.smallBadgeImage
    }
    
}
