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
            }, statusCheckDarwinNotificationName.rawValue, nil, .deliverImmediately)
        }
    }

    deinit {
        if isAppExtension {
            CFNotificationCenterRemoveEveryObserver(darwinNotifyCenter, selfAsOpaquePointer)
        }
    }

    func checkStatusInAppExtension() {
        CFNotificationCenterPostNotification(darwinNotifyCenter, statusCheckDarwinNotificationName, nil, nil, true)
    }

}
