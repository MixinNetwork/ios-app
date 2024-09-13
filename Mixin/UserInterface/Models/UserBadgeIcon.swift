import UIKit
import SDWebImage
import MixinServices

fileprivate let prosperityImage: SDAnimatedImage? = {
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
            prosperityImage
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
