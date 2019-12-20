import Foundation
import UserNotifications

public extension UNNotificationContent {
    
    enum UserInfoKey {
        static let conversationId = "mixin_conv_id"
        static let conversationCategory = "mixin_conv_catg"
        static let messageId = "mixin_msg_id"
        static let ownerUserId = "mixin_usr_id"
        static let ownerUserFullname = "mixin_usr_name"
        static let ownerUserIdentityNumber = "mixin_usr_idnum"
        static let ownerUserAvatarUrl = "mixin_usr_avtr"
        static let ownerUserAppId = "mixin_usr_app_id"
    }
    
}
