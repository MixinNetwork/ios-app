import Foundation
import MixinServices

final class ExpiredMessageManager {
    
    static let shared = ExpiredMessageManager()
    
    private let queue = DispatchQueue(label: "one.mixin.messenger.queue.ExpiredMessageManager")
    
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
                                       name: ExpiredMessageDAO.expiredAtDidUpdateNotification,
                                       object: nil)
    }
    
    @objc func removeExpiredMessages() {
        queue.async {
            ExpiredMessageDAO.shared.removeExpiredMessages { nextExpireAt in
                if let nextExpireAt = nextExpireAt {
                    self.scheduleTimer(expireAt: nextExpireAt)
                }
            }
        }
    }
    
    @objc private func applicationWillResignActive() {
        timer?.invalidate()
    }
    
    func isQueueAvailable(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global().async {
            let semaphore = DispatchSemaphore(value: 0)
            self.queue.async {
                semaphore.signal()
            }
            let result = semaphore.wait(timeout: .now() + 10)
            DispatchQueue.main.async {
                completion(result == .success)
            }
        }
    }
    
    private func scheduleTimer(expireAt: Int64) {
        let fireDate = Date(timeIntervalSince1970: TimeInterval(expireAt))
        if let timer = self.timer, timer.fireDate < fireDate {
            Logger.general.info(category: "ExpiredMessageManager", message: "Already scheduled timer on: \(timer.fireDate), abort to set to: \(fireDate)")
            return
        }
        timer?.invalidate()
        let timerInterval = fireDate.timeIntervalSinceNow
        Logger.general.info(category: "ExpiredMessageManager", message: "Scheduled timer after: \(timerInterval)s")
        timer = Timer.scheduledTimer(timeInterval: timerInterval,
                                     target: self,
                                     selector: #selector(self.removeExpiredMessages),
                                     userInfo: nil,
                                     repeats: false)
    }
    
}
