import Foundation
import MixinServices

struct MultisigURL {
    
    private static let scheme = "https"
    private static let host = "mixin.one"
    
    let id: String
    let action: MultisigAction
    
    init?(url: URL) {
        guard url.scheme == Self.scheme && url.host == Self.host else {
            return nil
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count == 4, pathComponents[1] == "safe", pathComponents[2] == "multisigs" else {
            return nil
        }
        
        let id = pathComponents[3]
        guard UUID.isValidLowercasedUUIDString(id) else {
            return nil
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        guard let actionValue = components.queryItems?.first(where: { $0.name == "action" })?.value else {
            return nil
        }
        guard let action = MultisigAction(rawValue: actionValue) else {
            return nil
        }
        
        self.id = id
        self.action = action
    }
    
}
