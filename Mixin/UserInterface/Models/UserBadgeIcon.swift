import UIKit
import MixinServices

enum UserBadgeIcon {
    
    static func image(
        membership: User.Membership?,
        isVerified: Bool,
        isBot: Bool
    ) -> UIImage? {
        if let image = membership?.badgeImage {
            image
        } else if isVerified {
            R.image.ic_user_verified()
        } else if isBot {
            R.image.ic_user_bot()
        } else {
            nil
        }
    }
    
    static func image(
        membership: User.Membership?,
        isVerified: Bool,
        appID: String?
    ) -> UIImage? {
        image(
            membership: membership,
            isVerified: isVerified,
            isBot: !appID.isNilOrEmpty
        )
    }
    
}

extension User.Membership {
    
    var badgeImage: UIImage? {
        guard expiredAt.timeIntervalSinceNow > 0 else {
            return nil
        }
        return switch plan {
        case .advance:
            R.image.user_membership_advance()
        case .elite:
            R.image.user_membership_elite()
        case .prosperity:
            R.image.user_membership_prosperity()
        case .none:
            nil
        }
    }
    
}

extension User {
    
    var badgeImage: UIImage? {
        UserBadgeIcon.image(
            membership: membership,
            isVerified: isVerified,
            appID: appId
        )
    }
    
}

extension UserItem {
    
    var badgeImage: UIImage? {
        UserBadgeIcon.image(
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
            UserBadgeIcon.image(
                membership: membership,
                isVerified: isVerified ?? false,
                appID: appID
            )
        case nil, .GROUP:
            nil
        }
    }
    
}
