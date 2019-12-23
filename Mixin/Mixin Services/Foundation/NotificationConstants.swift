import Foundation
import UserNotifications

enum NotificationActionIdentifier {
    static let reply = "reply"
    static let mute = "mute" // preserved
}

enum NotificationCategoryIdentifier {
    static let message = "message"
    static let call = "call"
}

enum NotificationRequestIdentifier {
    static let call = "call"
}

extension UNNotificationSound {
    
    static let mixin = UNNotificationSound(named: UNNotificationSoundName("mixin.caf"))
    static let call = UNNotificationSound(named: UNNotificationSoundName("call.caf"))
    
}

extension UNNotificationAction {
    
    static let reply = UNTextInputNotificationAction(identifier: NotificationActionIdentifier.reply,
                                                     title: Localized.NOTIFICATION_REPLY,
                                                     options: [])
    
}

public extension UNNotificationCategory {
    
    static let message = UNNotificationCategory(identifier: NotificationCategoryIdentifier.message,
                                                actions: [.reply],
                                                intentIdentifiers: [NotificationActionIdentifier.reply],
                                                options: [])
    
}
