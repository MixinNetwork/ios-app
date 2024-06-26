import Foundation
import GRDB

public class Asset: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord, TableRecord, PersistableRecord {
    
    public enum WithdrawalMemoPossibility: String {
        
        case positive
        case negative
        case possible
        
        public var isRequired: Bool {
            switch self {
            case .positive:
                return true
            case .negative, .possible:
                return false
            }
        }
        
        public init?(rawValue: String?) {
            guard let rawValue else {
                return nil
            }
            self.init(rawValue: rawValue)
        }
        
    }
    
    public struct DepositEntry: Codable {
        
        public let destination: String
        public let tag: String
        public let properties: [String]?
        
        public var payToWitness: Bool {
            properties?.contains("P2WPKH_V0") ?? false
        }
        
    }
    
    public class var databaseTableName: String {
        "assets"
    }
    
    public let assetId: String
    public let type: String
    public let symbol: String
    public let name: String
    public let iconUrl: String
    public let balance: String
    public let destination: String
    public let tag: String
    public let priceBtc: String
    public let priceUsd: String
    public let changeUsd: String
    public let chainId: String
    public let confirmations: Int
    public let assetKey: String
    public let reserve: String
    public let depositEntries: [DepositEntry]
    public let withdrawalMemoPossibility: String?
    
    public var preferredDepositEntry: DepositEntry? {
        if depositEntries.count > 1 {
            return depositEntries.first(where: \.payToWitness) ?? depositEntries.first
        } else {
            return depositEntries.first
        }
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        assetId = try container.decode(String.self, forKey: .assetId)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl) ?? ""
        balance = try container.decodeIfPresent(String.self, forKey: .balance) ?? ""
        destination = try container.decodeIfPresent(String.self, forKey: .destination) ?? ""
        tag = try container.decodeIfPresent(String.self, forKey: .tag) ?? ""
        priceBtc = try container.decodeIfPresent(String.self, forKey: .priceBtc) ?? ""
        priceUsd = try container.decodeIfPresent(String.self, forKey: .priceUsd) ?? ""
        changeUsd = try container.decodeIfPresent(String.self, forKey: .changeUsd) ?? ""
        chainId = try container.decodeIfPresent(String.self, forKey: .chainId) ?? ""
        confirmations = try container.decodeIfPresent(Int.self, forKey: .confirmations) ?? 0
        assetKey = try container.decodeIfPresent(String.self, forKey: .assetKey) ?? ""
        reserve = try container.decodeIfPresent(String.self, forKey: .reserve) ?? ""
        depositEntries = try container.decodeIfPresent([DepositEntry].self, forKey: .depositEntries) ?? []
        withdrawalMemoPossibility = try container.decodeIfPresent(String.self, forKey: .withdrawalMemoPossibility)
    }
    
    public init(assetId: String, type: String, symbol: String, name: String, iconUrl: String, balance: String, destination: String, tag: String, priceBtc: String, priceUsd: String, changeUsd: String, chainId: String, confirmations: Int, assetKey: String, reserve: String, depositEntries: [DepositEntry], withdrawalMemoPossibility: String?) {
        self.assetId = assetId
        self.type = type
        self.symbol = symbol
        self.name = name
        self.iconUrl = iconUrl
        self.balance = balance
        self.destination = destination
        self.tag = tag
        self.priceBtc = priceBtc
        self.priceUsd = priceUsd
        self.changeUsd = changeUsd
        self.chainId = chainId
        self.confirmations = confirmations
        self.assetKey = assetKey
        self.reserve = reserve
        self.depositEntries = depositEntries
        self.withdrawalMemoPossibility = withdrawalMemoPossibility
    }
    
    public enum CodingKeys: String, CodingKey {
        case assetId = "asset_id"
        case type
        case symbol
        case name
        case iconUrl = "icon_url"
        case balance
        case destination
        case tag
        case priceBtc = "price_btc"
        case priceUsd = "price_usd"
        case changeUsd = "change_usd"
        case chainId = "chain_id"
        case confirmations
        case assetKey = "asset_key"
        case reserve
        case depositEntries = "deposit_entries"
        case withdrawalMemoPossibility = "withdrawal_memo_possibility"
    }
    
}

extension Asset {
    
    public var usesTag: Bool {
        assetId == AssetID.xrp
    }
    
    public var isBitcoinChain: Bool {
        chainId == ChainID.bitcoin
    }
    
    public var isEOSChain: Bool {
        chainId == ChainID.eos
    }
    
    public var isERC20: Bool {
        chainId == ChainID.ethereum
    }
    
}

extension Asset {
    
    public var isDepositSupported: Bool {
        !Self.depositNotSupportedAssetIds.contains(assetId)
    }
    
    private static let depositNotSupportedAssetIds: Set<String> = [
        AssetID.mgd,
        AssetID.classicBTM,
        AssetID.omniUSDT,
    ]
    
}
