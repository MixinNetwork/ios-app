import Foundation
import AudioToolbox

class Vibrator {
    
    private var isVibrating = false
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?
    
    private weak var timer: Timer?
    
    func start() {
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
    
    func stop() {
        guard isVibrating else {
            return
        }
        endBackgroundTask()
        timer?.invalidate()
        isVibrating = false
    }
    
    private func endBackgroundTask() {
        guard let id = backgroundTaskIdentifier else {
            return
        }
        UIApplication.shared.endBackgroundTask(id)
        backgroundTaskIdentifier = nil
    }
    
}
