import Foundation
import MixinServices

final class DisappearingMessageManager {
    
    static let shared = DisappearingMessageManager()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.queue.disappearingMessage")
    
    private weak var timer: Timer?
    
    init() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(applicationWillResignActive),
                                       name: UIApplication.willResignActiveNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(removeExpiredMessages),
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
                    self?.scheduleTimer(expireAt: nextExpireAt)
                }
            }
        }
    }
    
    @objc private func applicationWillResignActive() {
        timer?.invalidate()
    }
    
    private func scheduleTimer(expireAt: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            let fireDate = Date(timeIntervalSince1970: TimeInterval(expireAt))
            if let timer = self.timer, timer.fireDate < fireDate {
                return
            }
            self.timer?.invalidate()
            let timerInterval = fireDate.timeIntervalSinceNow
            if timerInterval < 1 {
                self.removeExpiredMessages()
            } else {
                self.timer = Timer.scheduledTimer(timeInterval: timerInterval,
                                                  target: self,
                                                  selector: #selector(self.removeExpiredMessages),
                                                  userInfo: nil,
                                                  repeats: false)
            }
        }
    }
    
}
