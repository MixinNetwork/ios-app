import Foundation
import MixinServices

class SwapToken {
    
    let address: String
    let assetID: String
    let decimals: Int16
    let name: String
    let symbol: String
    let icon: String
    let chain: Chain
    
    var codable: Codable {
        Codable(
            address: address,
            assetID: assetID,
            decimals: decimals,
            name: name,
            symbol: symbol,
            icon: icon,
            chain: chain
        )
    }
    
    init(
        address: String, assetID: String, decimals: Int16,
        name: String, symbol: String, icon: String,
        chain: SwapToken.Chain
    ) {
        self.address = address
        self.assetID = assetID
        self.decimals = decimals
        self.name = name
        self.symbol = symbol
        self.icon = icon
        self.chain = chain
    }
    
}

extension SwapToken {
    
    var iconURL: URL? {
        URL(string: icon)
    }
    
    var chainTag: String? {
        switch chain.chainID {
        case ChainID.bnbSmartChain:
            "BEP-20"
        case ChainID.base:
            "Base"
        case assetID:
            nil
        case ChainID.ethereum:
            "ERC-20"
        case ChainID.tron:
            // To determine whether the chain is TRC-10 or TRC-20, the `asset_key` is required.
            // Currently, the Swap functionality does not support TRC-10 tokens, so we will handle this case simply.
            "TRC-20"
        case ChainID.eos:
            "EOS"
        case ChainID.polygon:
            "Polygon"
        case ChainID.solana:
            "Solana"
        default:
            nil
        }
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

extension SwapToken {
    
    struct Chain: Swift.Codable {
        
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
        
        init(chainID: String?, name: String, decimals: Int, symbol: String, icon: String) {
            self.chainID = chainID
            self.name = name
            self.decimals = decimals
            self.symbol = symbol
            self.icon = icon
        }
        
    }
    
    final class Codable: SwapToken, Swift.Codable {
        
        enum CodingKeys: String, CodingKey {
            case address
            case assetID = "assetId"
            case decimals
            case name
            case symbol
            case icon
            case chain
        }
        
        override init(
            address: String, assetID: String, decimals: Int16, name: String,
            symbol: String, icon: String, chain: SwapToken.Chain
        ) {
            super.init(
                address: address,
                assetID: assetID,
                decimals: decimals,
                name: name,
                symbol: symbol,
                icon: icon,
                chain: chain
            )
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            super.init(
                address: try container.decode(String.self, forKey: .address),
                assetID: try container.decode(String.self, forKey: .assetID),
                decimals: try container.decode(Int16.self, forKey: .decimals),
                name: try container.decode(String.self, forKey: .name),
                symbol: try container.decode(String.self, forKey: .symbol),
                icon: try container.decode(String.self, forKey: .icon),
                chain: try container.decode(Chain.self, forKey: .chain)
            )
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(address, forKey: .address)
            try container.encode(assetID, forKey: .assetID)
            try container.encode(decimals, forKey: .decimals)
            try container.encode(name, forKey: .name)
            try container.encode(symbol, forKey: .symbol)
            try container.encode(icon, forKey: .icon)
            try container.encode(chain, forKey: .chain)
        }
        
    }
    
}
