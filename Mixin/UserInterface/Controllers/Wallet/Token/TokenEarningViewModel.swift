import Foundation
import MixinServices

struct TokenEarningViewModel {
    
    private struct ProductCalculationModel: Comparable {
        
        let productionID: String
        let totalPrincipal: Decimal
        let totalEarnings: Decimal
        let redeemableEarnings: Decimal
        let minRate: Decimal?
        let maxRate: Decimal?
        
        init(product: EarnProduct) {
            let rates = product.annualRates.compactMap { rate in
                Decimal(string: rate, locale: .enUSPOSIX)
            }
            self.productionID = product.productionID
            self.totalPrincipal = Decimal(
                string: product.account.totalPrincipal,
                locale: .enUSPOSIX
            ) ?? 0
            self.totalEarnings = Decimal(
                string: product.account.totalEarnings,
                locale: .enUSPOSIX
            ) ?? 0
            self.redeemableEarnings = Decimal(
                string: product.account.redeemableEarnings,
                locale: .enUSPOSIX
            ) ?? 0
            self.minRate = rates.min()
            self.maxRate = rates.max()
        }
        
        static func > (lhs: ProductCalculationModel, rhs: ProductCalculationModel) -> Bool {
            (lhs.totalPrincipal, lhs.redeemableEarnings, lhs.maxRate ?? 0)
            > (rhs.totalPrincipal, rhs.redeemableEarnings, rhs.maxRate ?? 0)
        }
        
        static func < (lhs: ProductCalculationModel, rhs: ProductCalculationModel) -> Bool {
            (lhs.totalPrincipal, lhs.redeemableEarnings, lhs.maxRate ?? 0)
            < (rhs.totalPrincipal, rhs.redeemableEarnings, rhs.maxRate ?? 0)
        }
        
    }
    
    let totalEarnings: String
    let totalAmount: String
    let pendingEarning: String
    let rewardRate: String?
    let topProductionID: String
    
    init?(token: MixinTokenItem, products: [EarnProduct]) {
        let relatingProducts = products.filter { product in
            product.assetID == token.assetID
        }.map { product in
            ProductCalculationModel(product: product)
        }
        
        guard var topProduct = relatingProducts.first else {
            return nil
        }
        var totalEarnings: Decimal = 0
        var totalAmount: Decimal = 0
        var pendingEarning: Decimal = 0
        var minRate: Decimal?
        var maxRate: Decimal?
        for product in relatingProducts {
            totalEarnings += product.totalEarnings
            totalAmount += product.totalPrincipal
            pendingEarning += product.redeemableEarnings
            if let currentMinRate = minRate {
                if let productMinRate = product.minRate {
                    minRate = min(currentMinRate, productMinRate)
                }
            } else {
                minRate = product.minRate
            }
            if let currentMaxRate = maxRate {
                if let productMaxRate = product.maxRate {
                    maxRate = max(currentMaxRate, productMaxRate)
                }
            } else {
                maxRate = product.maxRate
            }
            if product > topProduct {
                topProduct = product
            }
        }
        
        self.totalEarnings = totalEarnings.formatted(
            Decimal.FormatStyle.Currency
                .currency(code: "USD")
                .presentation(.narrow)
                .precision(.fractionLength(0...2))
                .rounded(rule: .towardZero)
        )
        self.totalAmount = CurrencyFormatter.localizedString(
            from: totalAmount,
            format: .precision,
            sign: .never,
            symbol: .custom(token.symbol)
        )
        self.pendingEarning = pendingEarning.formatted(
            Decimal.FormatStyle.Currency
                .currency(code: "USD")
                .presentation(.narrow)
                .precision(.fractionLength(0...8))
                .rounded(rule: .towardZero)
        )
        if let minRate, let maxRate, minRate != maxRate {
            let minPercentage = PercentageFormatter.string(
                from: minRate,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero,
            )
            let maxPercentage = PercentageFormatter.string(
                from: maxRate,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero,
            )
            let percentage = minPercentage + " - " + maxPercentage
            self.rewardRate = R.string.localizable.cash_account_apy(percentage)
        } else if let rate = minRate ?? maxRate {
            let percentage = PercentageFormatter.string(
                from: rate,
                format: .pretty,
                sign: .never,
                options: .keepOneFractionDigitForZero,
            )
            self.rewardRate = R.string.localizable.cash_account_apy(percentage)
        } else {
            self.rewardRate = nil
        }
        self.topProductionID = topProduct.productionID
    }
    
}
