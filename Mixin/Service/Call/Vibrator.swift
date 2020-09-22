import Foundation
import AudioToolbox
import MixinServices

class Vibrator {
    
    private var isVibrating = false
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private weak var timer: Timer?
    
    func start() {
        DispatchQueue.main.async {
            guard !self.isVibrating else {
                return
            }
            self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: self.endBackgroundTask)
            self.isVibrating = true
            let timer = Timer(timeInterval: 1, repeats: true, block: { (_) in
                AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate, nil)
            })
            timer.fire()
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }
    
    func stop() {
        DispatchQueue.main.async {
            guard self.isVibrating else {
                return
            }
            self.endBackgroundTask()
            self.timer?.invalidate()
            self.isVibrating = false
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
