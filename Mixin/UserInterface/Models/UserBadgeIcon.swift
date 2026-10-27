import UIKit
import SDWebImage
import MixinServices

enum UserBadgeIcon {
    
    case membership(User.Membership.Plan)
    case verification
    case bot
    
    var smallImage: UIImage? {
        switch self {
        case .membership(let plan):
            plan.smallBadgeImage
        case .verification:
            R.image.badge_user_verified_small()
        case .bot:
            R.image.badge_app_small()
        }
    }
    
    init?(
        membership: User.Membership?,
        isVerified: Bool,
        isBot: Bool,
    ) {
        if let plan = membership?.unexpiredPlan {
            self = .membership(plan)
        } else if isVerified {
            self = .verification
        } else if isBot {
            self = .bot
        } else {
            return nil
        }
    }
    
}

extension UserBadgeIcon {
    
    static let smallProsperityImage: SDAnimatedImage? = {
        let resource = R.file.user_membership_prosperityJson.url()!
        let data = try! Data(contentsOf: resource)
        let size = CGSize(width: 18, height: 18) * UIScreen.main.scale
        let image = SDAnimatedImage(
            data: data,
            scale: UIScreen.main.scale,
            options: [.decodeThumbnailPixelSize: size]
        )
        return image
    }()
    
    static func smallImage(
        membership: User.Membership?,
        isVerified: Bool,
        isBot: Bool
    ) -> UIImage? {
        UserBadgeIcon(
            membership: membership,
            isVerified: isVerified,
            isBot: isBot
        )?.smallImage
    }
    
    static func smallImage(
        membership: User.Membership?,
        isVerified: Bool,
        identityNumber: String?
    ) -> UIImage? {
        let isBot = if let identityNumber {
            User.isBot(identityNumber: identityNumber)
        } else {
            false
        }
        return smallImage(
            membership: membership,
            isVerified: isVerified,
            isBot: isBot,
        )
    }
    
}

extension User.Membership.Plan {
    
    var smallBadgeImage: UIImage? {
        switch self {
        case .advance:
            R.image.membership_advance_small()
        case .elite:
            R.image.membership_elite_small()
        case .prosperity:
            UserBadgeIcon.smallProsperityImage
        }
    }
    
}

extension User {
    
    var badge: UserBadgeIcon? {
        UserBadgeIcon(
            membership: membership,
            isVerified: isVerified,
            isBot: isBot
        )
    }
    
}

extension UserItem {
    
    var badge: UserBadgeIcon? {
        UserBadgeIcon(
            membership: membership,
            isVerified: isVerified,
            isBot: isBot
        )
    }
    
}

extension CircleMember {
    
    var badgeImage: UIImage? {
        switch ConversationCategory(rawValue: category) {
        case .CONTACT:
            UserBadgeIcon.smallImage(
                membership: membership,
                isVerified: isVerified ?? false,
                isBot: isBot
            )
        case .GROUP:
            R.image.group_indicator_small()
        case nil:
            nil
        }
    }
    
}
