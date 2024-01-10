import Foundation
import MixinServices

struct CodeURL {
    
    private static let schemes = ["mixin", "https"]
    private static let host = "mixin.one"
    
    let uuid: String
    
    init?(url: URL) {
        guard let scheme = url.scheme, Self.schemes.contains(scheme) else {
            return nil
        }
        guard url.host == Self.host else {
            return nil
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3, pathComponents[1] == "scheme" else {
            return nil
        }
        
        let uuid = pathComponents[2]
        guard UUID.isValidLowercasedUUIDString(uuid) else {
            return nil
        }
        self.uuid = uuid
    }
    
}
