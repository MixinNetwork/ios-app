import Foundation
import MixinServices

struct MultisigURL {
    
    let id: String
    let action: MultisigAction
    
    init?(url: URL) {
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3, pathComponents[1] == "multisigs" else {
            return nil
        }
        
        let id = pathComponents[2]
        guard UUID.isValidLowercasedUUIDString(id) else {
            return nil
        }
        
        let action: MultisigAction
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }
        if let actionValue = components.queryItems?.first(where: { $0.name == "action" })?.value {
            if let multisigAction = MultisigAction(rawValue: actionValue) {
                action = multisigAction
            } else {
                return nil
            }
        } else {
            action = .sign
        }
        
        self.id = id
        self.action = action
    }
    
}
