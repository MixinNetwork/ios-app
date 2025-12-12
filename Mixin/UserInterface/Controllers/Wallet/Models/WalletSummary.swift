import Foundation
import MixinServices

struct WalletSummary {
    
    enum Symbol {
        
        case token(String)
        case other
        
        var localized: String {
            switch self {
            case let .token(symbol):
                symbol
            case .other:
                R.string.localizable.other()
            }
        }
        
    }
    
    struct Component {
        let symbol: Symbol
        let percentage: Decimal
    }
    
    let usdValue: Decimal
    let components: [Component]
    
    init(walletDigests: [WalletDigest]) {
        let maxNumberOfComponents = 3
        
        let wallets = walletDigests.filter { digest in
            switch digest.wallet {
            case .privacy:
                true
            case .common(let wallet):
                switch wallet.category.knownCase {
                case .classic, .importedMnemonic, .importedPrivateKey, .mixinSafe:
                    true
                case .watchAddress, .none:
                    // Watch wallets are excluded from calculation
                    false
                }
            }
        }
        let usdValues: [Token: Decimal] = wallets
            .flatMap(\.tokens)
            .reduce(into: [:]) { result, digest in
                let token = Token(digest: digest)
                let previousValue: Decimal = result[token] ?? 0
                result[token] = previousValue + digest.decimalValue
            }
        let usdValueSum = usdValues.values.reduce(0, +)
        var topComponents = Array(
            usdValues.map { token, value in
                let precentage = NSDecimalNumber(decimal: value / usdValueSum)
                    .rounding(accordingToBehavior: NSDecimalNumberHandler.percentRoundingHandler)
                    .decimalValue
                return Component(symbol: .token(token.symbol), percentage: precentage)
            }.sorted() { one, another in
                one.percentage > another.percentage
            }.prefix(maxNumberOfComponents)
        )
        
        if !topComponents.isEmpty {
            let precentageWithoutLast = topComponents
                .dropLast()
                .map(\.percentage)
                .reduce(0, +)
            let lastSymbol: Symbol = if usdValues.count > maxNumberOfComponents {
                .other
            } else {
                topComponents[topComponents.count - 1].symbol
            }
            topComponents[topComponents.count - 1] = Component(
                symbol: lastSymbol,
                percentage: 1 - precentageWithoutLast
            )
        }
        
        self.usdValue = usdValueSum
        self.components = topComponents
    }
    
}

extension WalletSummary {
    
    private struct Token: Equatable, Hashable {
        
        let assetID: String
        let symbol: String
        
        init(digest: TokenDigest) {
            self.assetID = digest.assetID
            self.symbol = digest.symbol
        }
        
        static func == (lhs: Token, rhs: Token) -> Bool {
            lhs.assetID == rhs.assetID
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(assetID)
        }
        
    }
    
}
