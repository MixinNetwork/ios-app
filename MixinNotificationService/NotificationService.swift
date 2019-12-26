import UserNotifications
import MixinServices

class NotificationService: UNNotificationServiceExtension {
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        guard LoginManager.shared.isLoggedIn, !AppGroupUserDefaults.needsMigration, !AppGroupUserDefaults.User.needsUpgradeInMainApp else {
            deliverBestAttemptContent()
            return
        }
        WebSocketService.shared.connect()
        
        
        if let bestAttemptContent = bestAttemptContent {
            // Modify the notification content here...
            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        deliverBestAttemptContent()
    }
    
    private func deliverBestAttemptContent() {
        guard let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent else {
            return
        }
        contentHandler(bestAttemptContent)
    }
    
}
