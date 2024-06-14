import Foundation
import MixinServices

struct CodeURL {
    
    let uuid: String
    
    init?(url: URL) {
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3, pathComponents[1] == "schemes" else {
            return nil
        }
        
        let uuid = pathComponents[2]
        guard UUID.isValidLowercasedUUIDString(uuid) else {
            return nil
        }
        self.uuid = uuid
    }
    
}
