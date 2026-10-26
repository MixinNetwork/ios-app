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
            plan.badgeImage
        case .verification:
            R.image.ic_user_verified()
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
    
    static let prosperityImage: SDAnimatedImage? = {
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
    
    static func image(
        membership: User.Membership?,
        isVerified: Bool,
        isBot: Bool
    ) -> UIImage? {
        let icon = UserBadgeIcon(
            membership: membership,
            isVerified: isVerified,
            isBot: isBot
        )
        return icon?.smallImage
    }
    
    static func image(
        membership: User.Membership?,
        isVerified: Bool,
        identityNumber: String?
    ) -> UIImage? {
        let isBot = if let identityNumber {
            User.isBot(identityNumber: identityNumber)
        } else {
            false
        }
        return image(
            membership: membership,
            isVerified: isVerified,
            isBot: isBot
        )
    }
    
}

extension User.Membership.Plan {
    
    var badgeImage: UIImage? {
        switch self {
        case .advance:
            R.image.membership_advance()
        case .elite:
            R.image.membership_elite()
        case .prosperity:
            UserBadgeIcon.prosperityImage
        }
    }
    
}

extension User.Membership {
    
    var badgeImage: UIImage? {
        unexpiredPlan?.badgeImage
    }
    
}

extension User {
    
    var badgeImage: UIImage? {
        UserBadgeIcon.image(
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
    
    var badgeImage: UIImage? {
        badge?.smallImage
    }
    
}

extension CircleMember {
    
    var badgeImage: UIImage? {
        switch ConversationCategory(rawValue: category) {
        case .CONTACT:
            UserBadgeIcon.image(
                membership: membership,
                isVerified: isVerified ?? false,
                isBot: isBot
            )
        case nil, .GROUP:
            nil
        }
    }
    
}
