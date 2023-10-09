import Foundation
import MixinServices

class BuyCryptoOrder {
    
    let asset: AssetItem
    let paymentAmount: Decimal
    let paymentCurrency: String
    let formatter: CheckoutAmountFormatter
    let initialTicker: BuyingTicker
    
    var ticker: BuyingTicker {
        initialTicker
    }
    
    var assetAmount: Decimal {
        paymentAmount / ticker.assetPrice
    }
    
    var receivedString: String {
        formatter.assetDisplayString(assetAmount) + " " + asset.symbol
    }
    
    var priceString: String {
        "1 \(asset.symbol) ≈ \(formatter.fiatMoneyDisplayString(ticker.assetPrice)) \(paymentCurrency)"
    }
    
    var feeByGatewayAmountString: String {
        formatter.fiatMoneyDisplayString(ticker.feeByGateway) + " " + ticker.currency
    }
    
    var feeByMixinAmountString: String {
        formatter.fiatMoneyDisplayString(ticker.feeByMixin) + " " + ticker.currency
    }
    
    var totalAmountString: String {
        formatter.fiatMoneyDisplayString(ticker.totalAmount) + " " + ticker.currency
    }
    
    var checkoutAmount: Int {
        formatter.checkoutAmount(paymentAmount)
    }
    
    init(
        asset: AssetItem,
        paymentAmount: Decimal,
        paymentCurrency: String,
        formatter: CheckoutAmountFormatter,
        initialTicker: BuyingTicker
    ) {
        self.asset = asset
        self.paymentAmount = paymentAmount
        self.paymentCurrency = paymentCurrency
        self.formatter = formatter
        self.initialTicker = initialTicker
    }
    
}

final class BuyCryptoConfirmedOrder: BuyCryptoOrder {
    
    let confirmedTicker: BuyingTicker
    
    override var ticker: BuyingTicker {
        confirmedTicker
    }
    
    override var assetAmount: Decimal {
        confirmedTicker.assetAmount
    }
    
    init(confirmedTicker: BuyingTicker, order: BuyCryptoOrder) {
        self.confirmedTicker = confirmedTicker
        super.init(asset: order.asset,
                   paymentAmount: order.paymentAmount,
                   paymentCurrency: order.paymentCurrency,
                   formatter: order.formatter,
                   initialTicker: order.initialTicker)
    }
    
}
