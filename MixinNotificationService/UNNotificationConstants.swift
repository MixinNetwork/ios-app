import Foundation
import MixinServices

public extension UNNotificationSound {
    
    static let mixin = UNNotificationSound(named: UNNotificationSoundName("mixin.caf"))
    static let call = UNNotificationSound(named: UNNotificationSoundName("call.caf"))
    
}

public extension UNNotificationAction {
    
    static let reply = UNTextInputNotificationAction(identifier: NotificationActionIdentifier.reply,
                                                     title: R.string.localizable.notification_reply(),
                                                     options: [])
    
}

public extension UNNotificationCategory {
    
    static let message = UNNotificationCategory(identifier: NotificationCategoryIdentifier.message,
                                                actions: [.reply],
                                                intentIdentifiers: [NotificationActionIdentifier.reply],
                                                options: [])
    
}
