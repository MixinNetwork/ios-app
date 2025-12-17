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
            case .privacy, .safe:
                CrossWalletTransaction.isFeeWaived
            case .common(let wallet):
                CrossWalletTransaction.isFeeWaived && wallet.hasSecret()
            }
        }
    }
    
}
