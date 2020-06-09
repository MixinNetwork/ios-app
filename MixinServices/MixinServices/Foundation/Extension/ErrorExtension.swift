import Foundation

public extension Error {
    
    var errorCode: Int {
        return (self as NSError).code
    }
    
}
