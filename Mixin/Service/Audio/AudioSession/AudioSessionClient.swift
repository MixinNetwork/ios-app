import Foundation
import AVFoundation

protocol AudioSessionClient: AnyObject {
    var priority: AudioSessionClientPriority { get }
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession, reason: AudioSession.InterruptionReason)
    func audioSessionDidEndInterruption(_ audioSession: AudioSession)
    func audioSession(_ audioSession: AudioSession, didChangeRouteFrom previousRoute: AVAudioSessionRouteDescription, reason: AVAudioSession.RouteChangeReason)
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession)
}

extension AudioSessionClient {
    
    func audioSessionDidBeganInterruption(_ audioSession: AudioSession, reason: AudioSession.InterruptionReason) {
        
    }
    
    func audioSessionDidEndInterruption(_ audioSession: AudioSession) {
        
    }
    
    func audioSession(_ audioSession: AudioSession, didChangeRouteFrom previousRoute: AVAudioSessionRouteDescription, reason: AVAudioSession.RouteChangeReason) {
        
    }
    
    func audioSessionMediaServicesWereReset(_ audioSession: AudioSession) {
        
    }
    
}
