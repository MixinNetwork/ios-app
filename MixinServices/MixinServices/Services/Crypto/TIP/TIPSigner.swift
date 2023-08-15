import Foundation

public struct TIPSigner: Decodable {
    
    public let identity: String
    public let index: Int
    public let api: String
    
    var apiURL: URL {
        URL(string: "https://" + MixinHost.current.api + api)!
    }
    
}

extension TIPSigner: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.index == rhs.index
    }
    
}
