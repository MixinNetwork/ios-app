import Foundation

public struct Web3Transaction {
    
    public let id: String
    public let transactionHash: String
    public let operationType: String
    public let status: String
    public let sender: String
    public let receiver: String
    public let fee: Fee
    public let transfers: [Transfer]
    public let approvals: [Approval]
    public let appMetadata: AppMetadata?
    public let createdAt: String
    
}

extension Web3Transaction: Decodable {
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case transactionHash = "transaction_hash"
        case operationType = "operation_type"
        case status = "status"
        case sender = "sender"
        case receiver = "receiver"
        case fee = "fee"
        case transfers = "transfers"
        case approvals = "approvals"
        case appMetadata = "app_metadata"
        case createdAt = "created_at"
    }
    
}

extension Web3Transaction {
    
    public enum TransactionType: String {
        case receive
        case send
        case deposit
        case withdraw
        case approve
        case borrow
        case burn
        case cancel
        case claim
        case deploy
        case execute
        case mint
        case repay
        case stake
        case trade
        case unstake
    }
    
    public enum Status: String {
        case pending
        case confirmed
        case failed
    }
    
    public struct AppMetadata: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case name = "name"
            case iconURL = "icon_url"
            case contractAddress = "contract_address"
            case methodID = "method_id"
            case methodName = "method_name"
        }
        
        public let name: String
        public let iconURL: String
        public let contractAddress: String
        public let methodID: String
        public let methodName: String
        
    }
    
    public struct Fee: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case name = "name"
            case symbol = "symbol"
            case iconURL = "icon_url"
            case sender = "sender"
            case amount = "amount"
            case price = "price"
        }
        
        public let name: String
        public let symbol: String
        public let iconURL: String
        public let sender: String?
        public let amount: String
        public let price: String?
        
    }
    
    public class Approval: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case name = "name"
            case symbol = "symbol"
            case iconURL = "icon_url"
            case sender = "sender"
            case amount = "amount"
        }
        
        public let name: String
        public let symbol: String
        public let iconURL: String
        public let sender: String
        public let amount: String
        
        public private(set) lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
        
    }
    
    public class Transfer: Decodable {
        
        public enum Direction: String {
            case `in`
            case out
            case `self`
        }
        
        enum CodingKeys: String, CodingKey {
            case name = "name"
            case symbol = "symbol"
            case iconURL = "icon_url"
            case direction = "direction"
            case sender = "sender"
            case amount = "amount"
            case price = "price"
        }
        
        public let name: String
        public let symbol: String
        public let iconURL: String
        public let direction: String
        public let sender: String
        public let amount: String
        public let price: String
        
        public private(set) lazy var decimalUSDPrice = Decimal(string: price, locale: .enUSPOSIX) ?? 0
        public private(set) lazy var decimalAmount = Decimal(string: amount, locale: .enUSPOSIX) ?? 0
        
        public private(set) lazy var localizedFiatMoneyAmount: String = {
            let value = decimalAmount * decimalUSDPrice * Currency.current.decimalRate
            return CurrencyFormatter.localizedString(from: value, format: .fiatMoney, sign: .never, symbol: .currencySymbol)
        }()
        
    }
    
}
