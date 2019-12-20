import Foundation
import Goutils

extension String {
    
    func toUUID() -> String {
        var digestData = self.utf8.md5.data
        
        digestData[6] &= 0x0f       // clear version
        digestData[6] |= 0x30       // set to version 3
        digestData[8] &= 0x3f       // clear variant
        digestData[8] |= 0x80       // set to IETF variant
        var error: NSError?
        return GoutilsUuidFromBytes(digestData, &error)
    }
    
}
