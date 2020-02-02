import Foundation
import UserNotifications

public extension UNNotificationContent {
    
    enum UserInfoKey {
        public static let conversationId = "mixin_conv_id"
        public static let conversationCategory = "mixin_conv_catg"
        public static let messageId = "mixin_msg_id"
        public static let ownerUserId = "mixin_usr_id"
        public static let ownerUserFullname = "mixin_usr_name"
        public static let ownerUserIdentityNumber = "mixin_usr_idnum"
        public static let ownerUserAvatarUrl = "mixin_usr_avtr"
        public static let ownerUserAppId = "mixin_usr_app_id"
    }
    
}
