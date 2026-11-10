import Foundation

enum WalletSearchCategory: CaseIterable, Hashable {
    
    case all
    case tokens
    case perps
    case earn
    case collectibles
    
    var title: String {
        switch self {
        case .all:
            R.string.localizable.all()
        case .tokens:
            R.string.localizable.assets()
        case .perps:
            R.string.localizable.positions()
        case .earn:
            R.string.localizable.earn()
        case .collectibles:
            R.string.localizable.collectibles()
        }
    }
    
}
