import Foundation
import GRDB

public struct Chain {
    
    public let chainId: String
    public let name: String
    public let symbol: String
    public let iconUrl: String
    public let threshold: Int
    public let withdrawalMemoPossibility: String
    
    public init(chainId: String, name: String, symbol: String, iconUrl: String, threshold: Int, withdrawalMemoPossibility: String) {
        self.chainId = chainId
        self.name = name
        self.symbol = symbol
        self.iconUrl = iconUrl
        self.threshold = threshold
        self.withdrawalMemoPossibility = withdrawalMemoPossibility
    }
    
}

extension Chain: Codable, DatabaseColumnConvertible, MixinFetchableRecord, MixinEncodableRecord {
    
    public enum CodingKeys: String, CodingKey {
        case chainId = "chain_id"
        case name
        case symbol
        case iconUrl = "icon_url"
        case threshold
        case withdrawalMemoPossibility = "withdrawal_memo_possibility"
    }
    
}

extension Chain: TableRecord, PersistableRecord {
    
    public static let databaseTableName = "chains"
    
}

extension Chain {
    
    public enum JoinedCodingKeys: String, CodingKey {
        case chainID = "chain_id"
        case chainName = "chain_name"
        case chainSymbol = "chain_symbol"
        case chainIconURL = "chain_icon_url"
        case chainThreshold = "chain_threshold"
        case chainWithdrawalMemoPossibility = "chain_withdrawal_memo_possibility"
    }
    
    public enum JoinedInitError: Error {
        case missingColumns
    }
    
    init(joinedDecoder decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedCodingKeys.self)
        if let id = try? container.decodeIfPresent(String.self, forKey: .chainID),
           let name = try? container.decodeIfPresent(String.self, forKey: .chainName),
           let symbol = try? container.decodeIfPresent(String.self, forKey: .chainSymbol),
           let iconURL = try? container.decodeIfPresent(String.self, forKey: .chainIconURL),
           let threshold = try? container.decodeIfPresent(Int.self, forKey: .chainThreshold),
           let withdrawalMemoPossibility = try? container.decodeIfPresent(String.self, forKey: .chainWithdrawalMemoPossibility)
        {
            self.init(
                chainId: id,
                name: name,
                symbol: symbol,
                iconUrl: iconURL,
                threshold: threshold,
                withdrawalMemoPossibility: withdrawalMemoPossibility
            )
        } else {
            throw JoinedInitError.missingColumns
        }
    }
    
}
