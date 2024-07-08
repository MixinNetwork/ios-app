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
    public let decimals: Int16
    public let name: String
    public let symbol: String
    public let icon: String
    public let source: String
    public let chain: Chain
    
    public var iconURL: URL? {
        URL(string: icon)
    }
    
    public func isEqual(to token: Web3Token) -> Bool {
        if address == Web3Token.AssetKey.wrappedSOL && token.assetKey == Web3Token.AssetKey.sol {
            true
        } else {
            // XXX: Really?
            address == token.assetKey
        }
    }
    
    public func decimalAmount(nativeAmount: Decimal) -> NSDecimalNumber? {
        let nativeAmountNumber = nativeAmount as NSDecimalNumber
        return nativeAmountNumber.multiplying(byPowerOf10: -decimals)
    }
    
}
