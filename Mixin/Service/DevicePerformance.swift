import Foundation
import MixinServices

enum DevicePerformance {
    case low    // A11 family and before
    case medium // A12 and A13 family
    case high   // A14 family and after
}

extension DevicePerformance {
    
    private enum Platform {
        
        case iPhone
        case iPodTouch
        case iPad
        case appleWatch
        case appleTV
        case unknown
        
        init(machineName name: String) {
            if name.hasPrefix("iPhone") {
                self = .iPhone
            } else if name.hasPrefix("iPad") {
                self = .iPad
            } else if name.hasPrefix("iPod") {
                self = .iPodTouch
            } else if name.hasPrefix("Watch") {
                self = .appleWatch
            } else if name.hasPrefix("AppleTV") {
                self = .appleTV
            } else {
                self = .unknown
            }
        }
        
    }
    
    private struct Version {
        
        let major: Int
        let minor: Int
        
        init?(machineName name: String) {
            guard let regex = try? NSRegularExpression(pattern: "[\\d]*,[\\d]*") else {
                return nil
            }
            let nsName = name as NSString
            let full = NSRange(location: 0, length: nsName.length)
            guard let match = regex.firstMatch(in: name, range: full) else {
                return nil
            }
            let value = nsName.substring(with: match.range)
            let components = value.components(separatedBy: ",")
            guard components.count == 2 else {
                return nil
            }
            guard let major = Int(components[0]), let minor = Int(components[1]) else {
                return nil
            }
            self.major = major
            self.minor = minor
        }
        
    }
    
    static let current: DevicePerformance = {
        let platform = Platform(machineName: Machine.current.name)
        let version = Version(machineName: Machine.current.name)
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
