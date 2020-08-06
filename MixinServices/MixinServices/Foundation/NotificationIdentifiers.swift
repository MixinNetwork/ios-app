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
