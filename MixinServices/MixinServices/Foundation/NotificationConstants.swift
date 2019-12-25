import Foundation
import UserNotifications

public enum NotificationActionIdentifier {
    public static let reply = "reply"
    public static let mute = "mute" // preserved
}

public enum NotificationCategoryIdentifier {
    public static let message = "message"
    public static let call = "call"
}

public enum NotificationRequestIdentifier {
    public static let call = "call"
}

public extension UNNotificationSound {
    
    static let mixin = UNNotificationSound(named: UNNotificationSoundName("mixin.caf"))
    static let call = UNNotificationSound(named: UNNotificationSoundName("call.caf"))
    
}

public extension UNNotificationAction {
    
    static let reply = UNTextInputNotificationAction(identifier: NotificationActionIdentifier.reply,
                                                     title: localized("notification_reply"),
                                                     options: [])
    
}

public extension UNNotificationCategory {
    
    static let message = UNNotificationCategory(identifier: NotificationCategoryIdentifier.message,
                                                actions: [.reply],
                                                intentIdentifiers: [NotificationActionIdentifier.reply],
                                                options: [])
    
}
