import Foundation
import MixinServices

final class WalletOverview {
    
    private(set) var value: String
    private(set) var btcValue: String?
    
    private let tokensValue: Decimal
    private let btcPrice: Decimal?
    
    private var perpsValue: Decimal
    
    init(tokensValue: Decimal, perpsValue: Decimal, btcPrice: Decimal?) {
        let usdValue = tokensValue + perpsValue
        self.value = CurrencyFormatter.localizedString(
            from: usdValue * Currency.current.decimalRate,
            format: .fiatMoneyPrecision,
            sign: .never,
        )
        self.btcValue = if let btcPrice {
            CurrencyFormatter.localizedString(
                from: usdValue / btcPrice,
                format: .precision,
                sign: .never,
                symbol: .custom("BTC")
            )
        } else {
            nil
        }
        self.tokensValue = tokensValue
        self.btcPrice = btcPrice
        self.perpsValue = perpsValue
    }
    
    func update(perpsValue: Decimal) {
        let usdValue = tokensValue + perpsValue
        self.value = CurrencyFormatter.localizedString(
            from: usdValue * Currency.current.decimalRate,
            format: .fiatMoneyPrecision,
            sign: .never,
        )
        self.btcValue = if let btcPrice {
            CurrencyFormatter.localizedString(
                from: usdValue / btcPrice,
                format: .precision,
                sign: .never,
                symbol: .custom("BTC")
            )
        } else {
            nil
        }
        self.perpsValue = perpsValue
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
