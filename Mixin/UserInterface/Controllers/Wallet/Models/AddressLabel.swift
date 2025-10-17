import Foundation
import MixinServices

enum AddressLabel {
    case addressBook(String)
    case wallet(Wallet)
    case contact(UserItem)
}
