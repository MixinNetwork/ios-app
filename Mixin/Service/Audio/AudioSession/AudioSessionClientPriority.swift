import Foundation

enum AudioSessionClientPriority: UInt {
    case playback = 0
    case audioRecord
    case voiceCall
}

extension AudioSessionClientPriority: Comparable {
    
    static func < (lhs: AudioSessionClientPriority, rhs: AudioSessionClientPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    static func <= (lhs: AudioSessionClientPriority, rhs: AudioSessionClientPriority) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }
    
    static func > (lhs: AudioSessionClientPriority, rhs: AudioSessionClientPriority) -> Bool {
        lhs.rawValue > rhs.rawValue
    }
    
    static func >= (lhs: AudioSessionClientPriority, rhs: AudioSessionClientPriority) -> Bool {
        lhs.rawValue >= rhs.rawValue
    }
    
}
