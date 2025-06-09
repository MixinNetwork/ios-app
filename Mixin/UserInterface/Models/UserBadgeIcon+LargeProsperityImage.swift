import UIKit
import SDWebImage

extension UserBadgeIcon {
    
    static let largeProsperityImage: SDAnimatedImage? = {
        let resource = R.file.user_membership_prosperity_largeJson.url()!
        let data = try! Data(contentsOf: resource)
        return SDAnimatedImage(data: data, scale: UIScreen.main.scale)
    }()
    
}
