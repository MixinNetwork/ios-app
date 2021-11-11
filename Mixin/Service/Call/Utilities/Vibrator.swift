import Foundation
import AudioToolbox
import MixinServices

class Vibrator {
    
    private var isVibrating = false
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    private weak var timer: Timer?
    
    @inlinable static func vibrateOnce() {
        AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate, nil)
    }
    
    func start() {
        Queue.main.autoAsync(execute: performStart)
    }
    
    func stop() {
        Queue.main.autoAsync(execute: performStop)
    }
    
}

extension Vibrator {
    
    func performStart() {
        guard !isVibrating else {
            return
        }
        isVibrating = true
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Vibrator", expirationHandler: performStop)
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Self.vibrateOnce()
        }
        timer.fire()
        self.timer = timer
    }
    
    func performStop() {
        guard isVibrating else {
            return
        }
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        }
        backgroundTaskIdentifier = .invalid
        timer?.invalidate()
        isVibrating = false
    }
    
}
