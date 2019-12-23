import Foundation
import WCDBSwift

extension WCDBSwift.Error: CustomNSError {
    
    public var errorUserInfo: [String : Any] {
        return ["desc": description]
    }
    
}
