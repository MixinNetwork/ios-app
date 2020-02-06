import Foundation

public class DarwinNotificationManager {

    public static let shared = DarwinNotificationManager()

    private let darwinNotifyCenter = CFNotificationCenterGetDarwinNotifyCenter()
    private var selfAsOpaquePointer: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    private init() {
        if isAppExtension {
            CFNotificationCenterAddObserver(darwinNotifyCenter, selfAsOpaquePointer, { (_, _, _, _, _) in
                AppGroupUserDefaults.isProcessingMessagesInAppExtension = ReceiveMessageService.shared.isProcessingMessagesInAppExtension
            }, checkStatusInAppExtensionDarwinNotificationName.rawValue, nil, .deliverImmediately)
        } else {
            CFNotificationCenterAddObserver(darwinNotifyCenter, selfAsOpaquePointer, { (_, _, _, _, _) in
                AppGroupUserDefaults.checkStatusTimeInMainApp = Date()
            }, checkStatusInMainAppDarwinNotificationName.rawValue, nil, .deliverImmediately)
        }
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(darwinNotifyCenter, selfAsOpaquePointer)
    }

    func checkStatusInAppExtension() {
        CFNotificationCenterPostNotification(darwinNotifyCenter, checkStatusInAppExtensionDarwinNotificationName, nil, nil, true)
    }

    func checkStatusInMainApp() {
        CFNotificationCenterPostNotification(darwinNotifyCenter, checkStatusInMainAppDarwinNotificationName, nil, nil, true)
    }

}
