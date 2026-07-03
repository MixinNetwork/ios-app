import Foundation
import MixinServices

final class WalletOverview {
    
    private(set) var value: String
    private(set) var btcValue: String?
    
    private let tokensValue: Decimal
    private let btcPrice: Decimal?
    
    private var perpsValue: Decimal
    private var cashValue: Decimal
    
    init(
        tokensValue: Decimal,
        perpsValue: Decimal,
        cashValue: Decimal,
        btcPrice: Decimal?
    ) {
        (self.value, self.btcValue) = Self.calculateValues(
            tokensValue: tokensValue,
            perpsValue: perpsValue,
            cashValue: cashValue,
            btcPrice: btcPrice
        )
        self.tokensValue = tokensValue
        self.btcPrice = btcPrice
        self.perpsValue = perpsValue
        self.cashValue = cashValue
    }
    
    func update(perpsValue: Decimal) {
        self.perpsValue = perpsValue
        (self.value, self.btcValue) = Self.calculateValues(
            tokensValue: tokensValue,
            perpsValue: perpsValue,
            cashValue: cashValue,
            btcPrice: btcPrice
        )
    }
    
    func update(cashValue: Decimal) {
        self.cashValue = cashValue
        (self.value, self.btcValue) = Self.calculateValues(
            tokensValue: tokensValue,
            perpsValue: perpsValue,
            cashValue: cashValue,
            btcPrice: btcPrice
        )
    }
    
}

extension WalletOverview {
    
    enum Action {
        case importSecret(ImportSecretAction)
        case general
    }
    
    enum ImportSecretAction {
        case importPrivateKey
        case importMnemonics
    }
    
    enum Tray {
        case watching(description: String)
        case pendingDeposits(tokens: [MixinToken], snapshots: [SafeSnapshot])
        case pendingTransactions([Web3Transaction])
    }
    
}

extension WalletOverview {
    
    private static func calculateValues(
        tokensValue: Decimal,
        perpsValue: Decimal,
        cashValue: Decimal,
        btcPrice: Decimal?,
    ) -> (value: String, btcValue: String?) {
        let usdValue = tokensValue + perpsValue + cashValue
        let value = CurrencyFormatter.localizedString(
            from: usdValue * Currency.current.decimalRate,
            format: .fiatMoneyPrecision,
            sign: .never,
        )
        let btcValue: String? = if let btcPrice {
            CurrencyFormatter.localizedString(
                from: usdValue / btcPrice,
                format: .precision,
                sign: .never,
                symbol: .custom("BTC")
            )
        } else {
            nil
        }
        return (value, btcValue)
    }
    
}
