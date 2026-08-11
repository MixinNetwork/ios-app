import Foundation

public enum MixinInternalURL {
    
    case identityNumber(String)
    case phoneNumber(String)
    
}

extension MixinInternalURL {
    
    public static let scheme = "mixin-internal"
    
    public enum Host {
        static let identityNumber = "identity"
        static let phoneNumber = "phone"
    }
    
    public init?(url: URL) {
        guard url.scheme == Self.scheme else {
            return nil
        }
        switch url.host {
        case Host.identityNumber where url.pathComponents.count == 2:
            self = .identityNumber(url.pathComponents[1])
        case Host.phoneNumber where url.pathComponents.count == 2:
            self = .phoneNumber(url.pathComponents[1])
        default:
            return nil
        }
    }
    
    public var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .identityNumber(let number):
            components.host = Host.identityNumber
            components.path = "/" + number
        case .phoneNumber(let number):
            components.host = Host.phoneNumber
            components.path = "/" + number
        }
        return components.url
    }
    
}
