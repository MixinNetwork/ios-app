import Foundation
import MixinServices

enum SequentialWalletNameGenerator {
    
    enum Category {
        case common
        case watch
    }
    
    static func nextNameIndex(category: Category) -> Int {
        let template = switch category {
        case .common:
            R.string.localizable.common_wallet_index("%")
        case .watch:
            R.string.localizable.watch_wallet_index("%")
        }
        let names = Web3WalletDAO.shared.walletNames(like: template)
        let indices = names.compactMap { name in
            name.components(separatedBy: " ").last
        }.compactMap { string in
            Int(string)
        }
        if let max = indices.max() {
            return max + 1
        } else {
            return 1
        }
    }
    
}
