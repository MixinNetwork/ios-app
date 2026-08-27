import Foundation
import MixinServices

struct EarnAccount {
    
    let usdBalance: Decimal
    let availableAssetIDs: Set<String>
    let iconURLs: [URL]
    
    init(products: [EarnProduct]) {
        assert(!Thread.isMainThread)
        var usdBalance: Decimal = 0
        var assetIDs: Set<String> = []
        var urls: [URL] = []
        for product in products {
            if let price = TokenDAO.shared.usdPrice(assetID: product.assetID) {
                var balance: Decimal = 0
                if let principal = Decimal(string: product.account.totalPrincipal, locale: .enUSPOSIX) {
                    balance += principal
                }
                if let earnings = Decimal(string: product.account.redeemableEarnings, locale: .enUSPOSIX) {
                    balance += earnings
                }
                usdBalance += balance * price
            }
            assetIDs.insert(product.assetID)
            if let url = URL(string: product.iconURL), !urls.contains(url) {
                urls.append(url)
            }
        }
        self.usdBalance = usdBalance
        self.availableAssetIDs = assetIDs
        self.iconURLs = urls
    }
    
}
