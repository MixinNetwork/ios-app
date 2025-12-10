import Foundation
import MixinServices

enum AddressLabel {
    
    case addressBook(String)
    case wallet(Wallet)
    case contact(UserItem)
    
    func isFeeWaived() -> Bool {
        switch self {
        case .addressBook:
            false
        case .contact:
            CrossWalletTransaction.isFeeWaived
        case .wallet(let wallet):
            switch wallet {
            case .privacy:
                CrossWalletTransaction.isFeeWaived
            case .common(let wallet):
                switch wallet.category.knownCase {
                case .mixinSafe:
                    true
                default:
                    CrossWalletTransaction.isFeeWaived && wallet.hasSecret()
                }
            }
        }
    }
    
}
