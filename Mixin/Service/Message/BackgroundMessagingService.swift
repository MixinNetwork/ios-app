import Foundation
import MixinServices

class BackgroundMessagingService {
    
    static let shared = BackgroundMessagingService()
    
    private var taskIdentifier = UIBackgroundTaskIdentifier.invalid
    
    private weak var backgroundTimer: Timer?
    private weak var stopTaskTimer: Timer?
    
    func end() {
        stopTaskTimer?.invalidate()
        backgroundTimer?.invalidate()
        if taskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(taskIdentifier)
            taskIdentifier = .invalid
        }
    }
    
    func begin(caller: String, stopsRegardlessApplicationState: Bool, completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        let startDate = Date()
        let application = UIApplication.shared
        end()
        requestTimeout = 3
        taskIdentifier = application.beginBackgroundTask(expirationHandler: {
            Logger.write(log: "[AppDelegate] \(caller)...hasCall:\(CallService.shared.hasCall)...expirationHandler...\(-startDate.timeIntervalSinceNow)s")
            if application.applicationState != .active && !CallService.shared.hasCall {
                MixinService.isStopProcessMessages = true
                WebSocketService.shared.disconnect()
            }
            AppGroupUserDefaults.isRunningInMainApp = ReceiveMessageService.shared.processing
            self.end()
            completionHandler?(.newData)
        })
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { (time) in
            AppGroupUserDefaults.isRunningInMainApp = ReceiveMessageService.shared.processing
            self.end()
            completionHandler?(.newData)
        }
        stopTaskTimer = Timer.scheduledTimer(withTimeInterval: 18, repeats: false) { (time) in
            guard stopsRegardlessApplicationState || application.applicationState != .active else {
                return
            }
            guard !CallService.shared.hasCall else {
                return
            }
            MixinService.isStopProcessMessages = true
            WebSocketService.shared.disconnect()
        }
    }
    
}
