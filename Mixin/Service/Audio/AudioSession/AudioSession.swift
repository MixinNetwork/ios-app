import Foundation
import AVFoundation
import MixinServices

class AudioSession {
    
    enum Error: Swift.Error {
        case insufficientPriority(AudioSessionClientPriority)
    }
    
    static let shared = AudioSession()
    
    let avAudioSession = AVAudioSession.sharedInstance()
    
    private let lock = NSLock()
    
    private weak var currentClient: AudioSessionClient?
    
    init() {
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(Self.audioSessionInterruption(_:)),
                           name: AVAudioSession.interruptionNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(Self.audioSessionRouteChange(_:)),
                           name: AVAudioSession.routeChangeNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(Self.audioSessionMediaServicesWereReset(_:)),
                           name: AVAudioSession.mediaServicesWereResetNotification,
                           object: nil)
    }
    
    func activate(client: AudioSessionClient, config: ((AVAudioSession) throws -> Void)? = nil) throws {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let currentClient = currentClient, currentClient !== client {
            if currentClient.priority > client.priority {
                throw Error.insufficientPriority(currentClient.priority)
            } else {
                if Thread.isMainThread {
                    currentClient.audioSessionDidBeganInterruption(self, reason: .default)
                } else {
                    DispatchQueue.main.sync {
                        currentClient.audioSessionDidBeganInterruption(self, reason: .default)
                    }
                }
            }
        }
        try config?(avAudioSession)
        try avAudioSession.setActive(true, options: [])
        currentClient = client
    }
    
    func deactivate(client: AudioSessionClient, notifyOthersOnDeactivation: Bool) throws {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard currentClient === client else {
            return
        }
        currentClient = nil
        let options: AVAudioSession.SetActiveOptions
        if notifyOthersOnDeactivation {
            options = .notifyOthersOnDeactivation
        } else {
            options = []
        }
        try avAudioSession.setActive(false, options: options)
    }
    
    func deactivateAsynchronously(client: AudioSessionClient, notifyOthersOnDeactivation: Bool) {
        DispatchQueue.global().async {
            try? self.deactivate(client: client, notifyOthersOnDeactivation: notifyOthersOnDeactivation)
        }
    }
    
    @objc private func audioSessionInterruption(_ notification: Notification) {
        guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber else {
            return
        }
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue.uintValue) else {
            return
        }
        switch type {
        case .began:
            let reason: AVAudioSession.InterruptionReason
            if #available(iOS 14.5, *) {
                if let rawValue = notification.userInfo?[AVAudioSessionInterruptionReasonKey] as? AVAudioSession.InterruptionReason.RawValue {
                    reason = AVAudioSession.InterruptionReason(rawValue: rawValue) ?? .default
                } else {
                    reason = .default
                }
            } else {
                let wasSuspended = notification.userInfo?[AVAudioSessionInterruptionWasSuspendedKey] as? Bool ?? false
                if wasSuspended {
                    reason = .appWasSuspended
                } else {
                    reason = .default
                }
            }
            currentClient?.audioSessionDidBeganInterruption(self, reason: reason)
        case .ended:
            currentClient?.audioSessionDidEndInterruption(self)
        @unknown default:
            break
        }
    }
    
    @objc private func audioSessionRouteChange(_ notification: Notification) {
        guard let previous = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else {
            return
        }
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber else {
            return
        }
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue.uintValue) else {
            return
        }
        currentClient?.audioSession(self, didChangeRouteFrom: previous, reason: reason)
    }
    
    @objc private func audioSessionMediaServicesWereReset(_ notification: Notification) {
        currentClient?.audioSessionMediaServicesWereReset(self)
    }
    
}
