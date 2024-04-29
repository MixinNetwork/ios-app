import Foundation
import MixinServices

extension MessageCategory {
    
    static func iconImage(forMessageCategoryString category: String) -> UIImage? {
        if category.hasSuffix("_IMAGE") {
            return #imageLiteral(resourceName: "ic_message_photo")
        } else if category.hasSuffix("_STICKER") {
            return #imageLiteral(resourceName: "ic_message_sticker")
        } else if category.hasSuffix("_CONTACT") {
            return #imageLiteral(resourceName: "ic_message_contact")
        } else if category.hasSuffix("_DATA") {
            return #imageLiteral(resourceName: "ic_message_file")
        } else if category.hasSuffix("_VIDEO") {
            return #imageLiteral(resourceName: "ic_message_video")
        } else if category.hasSuffix("_LIVE") {
            return R.image.ic_message_live()
        } else if category.hasSuffix("_AUDIO") {
            return #imageLiteral(resourceName: "ic_message_audio")
        } else if category.hasSuffix("_POST") {
            return R.image.ic_message_post()
        } else if category.hasSuffix("_LOCATION") {
            return R.image.ic_message_location()
        } else if category.hasSuffix("_TRANSCRIPT") {
            return R.image.ic_message_transcript()
        } else if ["SYSTEM_ACCOUNT_SNAPSHOT", "SYSTEM_SAFE_SNAPSHOT", "SYSTEM_SAFE_INSCRIPTION"].contains(category) {
            return #imageLiteral(resourceName: "ic_message_transfer")
        } else if ["WEBRTC_", "KRAKEN_"].contains(where: category.hasPrefix(_:)) {
            return R.image.ic_message_call()
        } else if category == MessageCategory.MESSAGE_RECALL.rawValue {
            return R.image.ic_message_recalled()
        } else if category == MessageCategory.APP_BUTTON_GROUP.rawValue || category == MessageCategory.APP_CARD.rawValue {
            return #imageLiteral(resourceName: "ic_message_bot_menu")
        } else {
            return nil
        }
    }
    
}
