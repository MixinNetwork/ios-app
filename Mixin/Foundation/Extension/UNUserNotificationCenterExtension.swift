import Foundation
import UserNotifications
import UIKit

extension UNUserNotificationCenter {
    
    func sendCallNotification(callerName: String) {
        let content = UNMutableNotificationContent()
        content.title = callerName
        content.body = Localized.ALERT_KEY_CONTACT_AUDIO_CALL_MESSAGE
        content.sound = .call
        content.categoryIdentifier = NotificationCategoryIdentifier.call
        let request = UNNotificationRequest(identifier: NotificationRequestIdentifier.call,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    func removeNotifications(withIdentifiers identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
}
