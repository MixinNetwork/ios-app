import Foundation

enum MixinInternalURL {
    
    static let scheme = "mixin-internal"
    
    enum Host {
        static let identityNumber = "identity-number"
    }
    
    case identityNumber(String)
    
    init?(url: URL) {
        guard url.scheme == Self.scheme else {
            return nil
        }
        switch url.host {
        case Host.identityNumber where url.pathComponents.count == 2:
            self = .identityNumber(url.pathComponents[1])
        default:
            return nil
        }
    }
    
    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .identityNumber(let number):
            components.host = Host.identityNumber
            components.path = "/" + number
        }
        return components.url
    }
    
}
