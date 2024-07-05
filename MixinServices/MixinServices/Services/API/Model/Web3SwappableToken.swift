import Foundation

public struct Web3SwappableToken: Decodable {
    
    public struct Chain: Decodable {
        
        public let name: String
        public let decimals: Int
        public let symbol: String
        public let icon: String
        
        public var iconURL: URL? {
            URL(string: icon)
        }
        
    }
    
    public let address: String
    public let decimals: Int
    public let name: String
    public let symbol: String
    public let icon: String
    public let source: String
    public let chain: Chain
    
    public var iconURL: URL? {
        URL(string: icon)
    }
    
}
