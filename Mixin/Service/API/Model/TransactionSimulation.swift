import Foundation
import MixinServices

struct TransactionSimulation {
    
    static let empty = TransactionSimulation(balanceChanges: nil, approves: nil)
    
    let balanceChanges: [BalanceChange]?
    let approves: [Approve]?
    
    private init(balanceChanges: [BalanceChange]?, approves: [Approve]?) {
        self.balanceChanges = balanceChanges
        self.approves = approves
    }
    
    static func balanceChange(
        token: Web3TokenItem,
        amount: Decimal
    ) -> TransactionSimulation {
        TransactionSimulation(
            balanceChanges: [
                BalanceChange(token: token, amount: amount)
            ],
            approves: nil
        )
    }
    
}

extension TransactionSimulation: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case balanceChanges = "balance_changes"
        case approves
    }
    
}

extension TransactionSimulation {
    
    struct Approve: Decodable, Token {
        
        enum CodingKeys: String, CodingKey {
            case spender = "spender"
            case assetID = "asset_id"
            case assetKey = "asset_key"
            case amount = "amount"
            case decimals = "decimals"
            case name = "name"
            case symbol = "symbol"
            case iconURL = "icon"
        }
        
        enum Amount: Decodable {
            
            case unlimited
            case limited(Decimal)
            
            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(String.self)
                if rawValue == "unlimited" {
                    self = .unlimited
                } else if let value = Decimal(string: rawValue, locale: .enUSPOSIX) {
                    self = .limited(value)
                } else {
                    throw DecodingError.dataCorrupted(
                        .init(
                            codingPath: [CodingKeys.amount],
                            debugDescription: "Invalid amount"
                        )
                    )
                }
            }
            
        }
        
        let spender: String
        let assetID: String
        let assetKey: String
        let amount: Amount
        let decimals: Int
        let name: String
        let symbol: String
        let iconURL: String
        
    }
    
}
