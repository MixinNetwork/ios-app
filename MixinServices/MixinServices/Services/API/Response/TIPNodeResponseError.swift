import Foundation

public struct TIPNodeResponseError: Error, Decodable, Equatable {
    
    public static let tooManyRequests = TIPNodeResponseError(code: 429)
    public static let incorrectPIN = TIPNodeResponseError(code: 403)
    public static let internalServer = TIPNodeResponseError(code: 500)
    
    public let code: Int
    
    var isFatal: Bool {
        [.tooManyRequests, .incorrectPIN, .internalServer].contains(self)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.code == rhs.code
    }
    
}
