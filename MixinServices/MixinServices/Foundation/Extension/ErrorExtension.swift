import Foundation

public extension Error {
    
    var errorCode: Int {
        return (self as NSError).code
    }
    
    var localizedDescription: String {
        return (self as NSError).localizedDescription
    }
    
}
