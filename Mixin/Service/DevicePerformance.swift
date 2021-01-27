import Foundation
import DeviceGuru

enum DevicePerformance {
    case low    // A11 family and before
    case medium // A12 and A13 family
    case high   // A14 family and after
}

extension DevicePerformance {
    
    static let current: DevicePerformance = {
        let guru = DeviceGuru()
        let platform = guru.platform()
        let version = guru.deviceVersion()
        switch platform {
        case .iPhone:
            if let version = version {
                if version.major < 11 {
                    return .low
                } else if version.major < 13 {
                    return .medium
                } else {
                    return .high
                }
            } else {
                return .high
            }
        case .iPad:
            if let version = version {
                if version.major < 8 {
                    return .low
                } else if version.major < 13 {
                    return .medium
                } else {
                    return .high
                }
            } else {
                return .high
            }
        case .iPodTouch:
            return .low
        case .appleTV, .appleWatch, .unknown:
            assertionFailure("New devices get supported?")
            return .low
        }
    }()
    
}
