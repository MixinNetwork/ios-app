import Foundation
import MixinServices

struct WalletOverview {
    
    let value: String
    let btcValue: String?
    
    init(usdValue: Decimal, btcPrice: Decimal?) {
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
