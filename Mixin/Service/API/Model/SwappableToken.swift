import Foundation
import MixinServices

final class SwappableToken: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case address
        case assetID = "assetId"
        case decimals
        case name
        case symbol
        case icon
        case source
        case chain
    }
    
    let address: String
    let assetID: String
    let decimals: Int16
    let name: String
    let symbol: String
    let icon: String
    let source: RouteTokenSource
    let chain: Chain
    
    var iconURL: URL? {
        URL(string: icon)
    }
    
    init(
        address: String, assetID: String, decimals: Int16,
        name: String, symbol: String, icon: String,
        source: RouteTokenSource, chain: SwappableToken.Chain
    ) {
        self.address = address
        self.assetID = assetID
        self.decimals = decimals
        self.name = name
        self.symbol = symbol
        self.icon = icon
        self.source = source
        self.chain = chain
    }
    
    func isEqual(to token: Web3Token) -> Bool {
        if address == Web3Token.AssetKey.wrappedSOL && token.assetKey == Web3Token.AssetKey.sol {
            true
        } else {
            address == token.assetKey
        }
    }
    
    func decimalAmount(nativeAmount: Decimal) -> NSDecimalNumber? {
        let nativeAmountNumber = nativeAmount as NSDecimalNumber
        return nativeAmountNumber.multiplying(byPowerOf10: -decimals)
    }
    
}

extension SwappableToken {
    
    struct Chain: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case chainID = "chainId"
            case name
            case decimals
            case symbol
            case icon
        }
        
        let chainID: String?
        let name: String
        let decimals: Int
        let symbol: String
        let icon: String
        
        var iconURL: URL? {
            URL(string: icon)
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let id = try container.decodeIfPresent(String.self, forKey: .chainID), !id.isEmpty {
                self.chainID = id
            } else {
                self.chainID = nil
            }
            self.name = try container.decode(String.self, forKey: .name)
            self.decimals = try container.decode(Int.self, forKey: .decimals)
            self.symbol = try container.decode(String.self, forKey: .symbol)
            self.icon = try container.decode(String.self, forKey: .icon)
        }
        
    }
    
}