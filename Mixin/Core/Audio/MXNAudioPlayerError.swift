import Foundation

enum MXNAudioPlayerError: _ObjectiveCBridgeableError {
    
    public var _domain: String {
        return MXNAudioPlayerErrorDomain
    }
    
    public init?(_bridgedNSError error: NSError) {
        guard error.domain == MXNAudioPlayerErrorDomain else {
            return nil
        }
        switch error.code {
        case Int(MXNAudioPlayerErrorCode.newOutput.rawValue):
            self = .newOutput
        case Int(MXNAudioPlayerErrorCode.allocateBuffers.rawValue):
            self = .allocateBuffers
        case Int(MXNAudioPlayerErrorCode.addPropertyListener.rawValue):
            self = .addPropertyListener
        case Int(MXNAudioPlayerErrorCode.stop.rawValue):
            self = .stop
        case Int(MXNAudioPlayerErrorCode.cancelled.rawValue):
            self = .cancelled
        default:
            return nil
        }
    }
    
    case newOutput
    case allocateBuffers
    case addPropertyListener
    case stop
    case cancelled
    
}
