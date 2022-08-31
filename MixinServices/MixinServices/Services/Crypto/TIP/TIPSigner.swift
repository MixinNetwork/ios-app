import Foundation

public struct TIPSigner: Decodable {
    
    public let identity: String
    public let index: Int
    public let api: URL
    
}

extension TIPSigner: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.index == rhs.index
    }
    
}
