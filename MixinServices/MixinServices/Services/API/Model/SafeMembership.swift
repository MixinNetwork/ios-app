import Foundation

public struct SafeMembership: Decodable {
    
    public enum Plan: String, CaseIterable, Decodable {
        
        case basic
        case standard
        case premium
        
        public init(userMembershipPlan plan: User.Membership.Plan) {
            switch plan {
            case .advance:
                self = .basic
            case .elite:
                self = .standard
            case .prosperity:
                self = .premium
            }
        }
        
    }
    
    public struct PlanDetail: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case plan = "plan"
            case accountQuota = "account_quota"
            case transactionQuota = "transaction_quota"
            case accountantsQuota = "accountants_quota"
            case membersQuota = "members_quota"
            case amount = "amount"
            case discountAmount = "amount_discount"
            case paymentAmount = "amount_payment"
            case appleSubscriptionID = "apple_subscription_id"
        }
        
        public let plan: Plan
        public let accountQuota: Int
        public let transactionQuota: Int
        public let accountantsQuota: Int
        public let membersQuota: Int
        public let amount: String
        public let discountAmount: String
        public let paymentAmount: String
        public let appleSubscriptionID: String
        
    }
    
    public struct Transaction: Decodable {
        
        enum CodingKeys: String, CodingKey {
            case assetID = "asset_id"
            case fee = "fee"
            case recoveryFee = "recovery_fee"
        }
        
        public let assetID: String
        public let fee: Decimal
        public let recoveryFee: Decimal
        
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.assetID = try container.decode(String.self, forKey: .assetID)
            self.fee = try container.decode(Decimal.self, forKey: .fee)
            self.recoveryFee = try container.decode(Decimal.self, forKey: .recoveryFee)
        }
        
    }
    
    public let plans: [PlanDetail]
    public let transaction: Transaction
    
}
