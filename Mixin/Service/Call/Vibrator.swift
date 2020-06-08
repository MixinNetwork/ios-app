import Foundation
import AudioToolbox
import MixinServices

class Vibrator {
    
    private var isVibrating = false
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private weak var timer: Timer?
    
    func start() {
        performSynchronouslyOnMainThread {
            guard !isVibrating else {
                return
            }
            backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: endBackgroundTask)
            isVibrating = true
            let timer = Timer(timeInterval: 1, repeats: true, block: { (_) in
                AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate, nil)
            })
            timer.fire()
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }
    
    func stop() {
        performSynchronouslyOnMainThread {
            guard isVibrating else {
                return
            }
            endBackgroundTask()
            timer?.invalidate()
            isVibrating = false
        }
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }
    
}
