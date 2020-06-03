import Foundation
import MixinServices

class BackgroundMessagingService {
    
    static let shared = BackgroundMessagingService()
    
    private var taskIdentifier = UIBackgroundTaskIdentifier.invalid
    
    private weak var backgroundTimer: Timer?
    private weak var stopTaskTimer: Timer?
    
    func stop() {
        stopTaskTimer?.invalidate()
        backgroundTimer?.invalidate()
        if taskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(taskIdentifier)
            taskIdentifier = .invalid
        }
    }
    
    func begin(caller: String, stopsRegarlessApplicationState: Bool, completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        let startDate = Date()
        let application = UIApplication.shared
        stop()
        requestTimeout = 3
        taskIdentifier = application.beginBackgroundTask(expirationHandler: {
            Logger.write(log: "[AppDelegate] \(caller)...expirationHandler...\(-startDate.timeIntervalSinceNow)s")
            if application.applicationState != .active {
                MixinService.isStopProcessMessages = true
                WebSocketService.shared.disconnect()
            }
            AppGroupUserDefaults.isRunningInMainApp = ReceiveMessageService.shared.processing
            self.stop()
            completionHandler?(.newData)
        })
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { (time) in
            AppGroupUserDefaults.isRunningInMainApp = ReceiveMessageService.shared.processing
            self.stop()
            completionHandler?(.newData)
        }
        stopTaskTimer = Timer.scheduledTimer(withTimeInterval: 18, repeats: false) { (time) in
            guard stopsRegarlessApplicationState || application.applicationState != .active else {
                return
            }
            MixinService.isStopProcessMessages = true
            WebSocketService.shared.disconnect()
        }
    }
    
}
