import Foundation
import MixinServices

extension Wallet {
    
    var tradeOrderWalletID: String {
        switch self {
        case .privacy:
            myUserId
        case .common(let wallet):
            wallet.walletID
        case .safe(let wallet):
            wallet.walletID
        }
    }
    
}
