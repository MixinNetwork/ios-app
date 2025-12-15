import Foundation
import OrderedCollections
import MixinServices

enum WalletDisplayCategory {
    
    case all
    case safe
    case created
    case imported
    case watching
    
    var localizedName: String {
        switch self {
        case .all:
            R.string.localizable.all()
        case .safe:
            R.string.localizable.wallet_category_safe()
        case .created:
            R.string.localizable.wallet_category_created()
        case .imported:
            R.string.localizable.wallet_category_imported()
        case .watching:
            R.string.localizable.wallet_category_watching()
        }
    }
    
}

extension WalletDisplayCategory {
    
    typealias CategorizedWalletDigests = OrderedDictionary<WalletDisplayCategory, [WalletDigest]>
    
    static func categorize(digests: [WalletDigest]) -> CategorizedWalletDigests {
        // Empty arrays for the ordering
        var results: CategorizedWalletDigests = [
            .all: digests,
            .safe: [],
            .created: [],
            .imported: [],
            .watching: [],
        ]
        for digest in digests {
            let category: WalletDisplayCategory? = switch digest.wallet {
            case .privacy:
                nil
            case .common(let wallet):
                switch wallet.category.knownCase {
                case .classic:
                        .created
                case .importedMnemonic, .importedPrivateKey:
                        .imported
                case .watchAddress:
                        .watching
                case .mixinSafe:
                        .safe
                case .none:
                        .none
                }
            }
            if let category {
                var wallets = results[category] ?? []
                wallets.append(digest)
                results[category] = wallets
            }
        }
        for key in results.keys {
            switch key {
            case .all:
                break
            default:
                results[key]?.sort { one, another in
                    one.usdBalanceSum > another.usdBalanceSum
                }
            }
        }
        return results
    }
    
}
