import Foundation
import MixinServices

struct CashAccount {
    
    let balance: String
    let minAmount: String
    let rewardAPY: String
    
    let decimalBalance: Decimal
    let displayBalance: String
    let decimalMinAmount: Decimal
    let displayAPY: String
    
}

extension CashAccount: Codable {
    
    enum CodingKeys: String, CodingKey {
        case balance = "balance"
        case minAmount = "min_amount"
        case rewardAPY = "reward_apy"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let balance = try container.decode(String.self, forKey: .balance)
        let decimalBalance = Decimal(string: balance, locale: .enUSPOSIX) ?? 0
        
        self.balance = balance
        self.minAmount = try container.decode(String.self, forKey: .minAmount)
        self.rewardAPY = try container.decode(String.self, forKey: .rewardAPY)
        self.decimalBalance = decimalBalance
        self.displayBalance = CurrencyFormatter.localizedString(
            from: decimalBalance,
            format: .fiatMoneyPrecision,
            sign: .never
        )
        self.decimalMinAmount = Decimal(string: minAmount, locale: .enUSPOSIX) ?? 5
        self.displayAPY = if let apy = Decimal(string: rewardAPY, locale: .enUSPOSIX) {
            R.string.localizable.cash_account_apy(
                PercentageFormatter.string(from: apy / 100, format: .pretty, sign: .never)
            )
        } else {
            ""
        }
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(balance, forKey: .balance)
        try container.encode(minAmount, forKey: .minAmount)
        try container.encode(rewardAPY, forKey: .rewardAPY)
    }
    
}
