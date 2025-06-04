import Foundation

public struct SafeMembership: Decodable {
    
    public enum Plan: String, CaseIterable, Decodable, Comparable {
        
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
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.basic, .standard), (.standard, .premium):
                true
            default:
                false
            }
        }
        
        public static func > (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.standard, .basic), (.premium, .standard):
                true
            default:
                false
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
        
        public init(
            plan: Plan, accountQuota: Int, transactionQuota: Int,
            accountantsQuota: Int, membersQuota: Int,
            amount: String, discountAmount: String,
            paymentAmount: String, appleSubscriptionID: String
        ) {
            self.plan = plan
            self.accountQuota = accountQuota
            self.transactionQuota = transactionQuota
            self.accountantsQuota = accountantsQuota
            self.membersQuota = membersQuota
            self.amount = amount
            self.discountAmount = discountAmount
            self.paymentAmount = paymentAmount
            self.appleSubscriptionID = appleSubscriptionID
        }
        
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
            self.fee = try container.decodeStringAsDecimal(forKey: .fee)
            self.recoveryFee = try container.decodeStringAsDecimal(forKey: .recoveryFee)
        }
        
    }
    
    public let plans: [PlanDetail]
    public let transaction: Transaction
    
}
