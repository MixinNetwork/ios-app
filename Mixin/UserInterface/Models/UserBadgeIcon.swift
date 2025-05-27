import UIKit
import SDWebImage
import MixinServices

enum UserBadgeIcon {
    
    private static let prosperityImageData = try! Data(contentsOf: R.file.user_membership_prosperityJson.url()!)
    
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
    
    static func prosperityImage(dimension: CGFloat) -> SDAnimatedImage? {
        let size = CGSize(
            width: dimension * UIScreen.main.scale,
            height: dimension * UIScreen.main.scale
        )
        return SDAnimatedImage(
            data: prosperityImageData,
            scale: UIScreen.main.scale,
            options: [.decodeThumbnailPixelSize: size]
        )
    }
    
}

extension User.Membership {
    
    var badgeImage: UIImage? {
        switch unexpiredPlan {
        case .advance:
            R.image.membership_advance()
        case .elite:
            R.image.membership_elite()
        case .prosperity:
            UserBadgeIcon.prosperityImage(dimension: 18)
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
            isBot: isBot
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
                isBot: isBot
            )
        case nil, .GROUP:
            nil
        }
    }
    
}
