import Foundation
import MixinServices

final class DisappearingMessageManager {
    
    static let shared = DisappearingMessageManager()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.queue.disappearingMessage")
    
    private var disappearanceDate: Date = .distantFuture
    
    private weak var disappearanceTimer: Timer?
    
    init() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillResignActive),
                                       name: UIApplication.willResignActiveNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationDidBecomeActive),
                                       name: UIApplication.didBecomeActiveNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(removeExpiredMessages),
                                       name: DisappearingMessageDAO.expiredAtDidUpdateNotification,
                                       object: nil)
    }
    
    @objc func removeExpiredMessages() {
        queue.async { [weak self] in
            DisappearingMessageDAO.shared.removeExpiredMessages { nextExpireAt in
                if let nextExpireAt = nextExpireAt {
                    self?.schedualTimer(expireAt: nextExpireAt)
                }
            }
        }
    }
    
    @objc private func applicationWillResignActive() {
        resetDisappearanceTimer()
    }
    
    @objc private func applicationDidBecomeActive() {
        removeExpiredMessages()
    }
    
    @objc private func disappearanceTimerDidFire() {
        guard AppGroupUserDefaults.isRunningInMainApp else {
            return
        }
        resetDisappearanceTimer()
        removeExpiredMessages()
    }
    
    private func schedualTimer(expireAt: UInt64) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            guard AppGroupUserDefaults.isRunningInMainApp else {
                return
            }
            let delaySeconds = Date(timeIntervalSince1970: TimeInterval(expireAt)).timeIntervalSinceNow
            let newTimerScheduleDate = Date(timeIntervalSinceNow: delaySeconds)
            if self.disappearanceDate < newTimerScheduleDate {
                return
            }
            self.resetDisappearanceTimer()
            self.disappearanceDate = newTimerScheduleDate
            self.disappearanceTimer = Timer.scheduledTimer(timeInterval: delaySeconds,
                                                           target: self,
                                                           selector: #selector(self.disappearanceTimerDidFire),
                                                           userInfo: nil,
                                                           repeats: false)
            RunLoop.main.add(self.disappearanceTimer!, forMode: .common)
        }
    }
    
    private func resetDisappearanceTimer() {
        disappearanceTimer?.invalidate()
        disappearanceTimer = nil
        disappearanceDate = .distantFuture
    }
    
}

