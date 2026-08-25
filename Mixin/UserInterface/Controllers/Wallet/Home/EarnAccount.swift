import Foundation

struct EarnAccount {
    
    let balance: Decimal
    let iconURLs: [URL]
    
    init(products: [EarnProduct]) {
        var balance: Decimal = 0
        var urls: [URL] = []
        for product in products {
            if let principal = Decimal(string: product.account.totalPrincipal, locale: .enUSPOSIX) {
                balance += principal
            }
            if let earnings = Decimal(string: product.account.redeemableEarnings, locale: .enUSPOSIX) {
                balance += earnings
            }
            if let url = URL(string: product.iconURL), !urls.contains(url) {
                urls.append(url)
            }
        }
        self.balance = balance
        self.iconURLs = urls
    }
    
}
