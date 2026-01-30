import Foundation
import OrderedCollections
import MixinServices

enum WalletDisplayCategory: Int {
    
    case all        = 0
    case safe       = 1
    case created    = 2
    case imported   = 3
    case watching   = 4
    
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
    
    var summaryTip: String? {
        switch self {
        case .all:
            R.string.localizable.wallet_summary_tip_all()
        case .safe:
            R.string.localizable.wallet_summary_tip_safe()
        case .created, .imported:
            R.string.localizable.wallet_summary_tip_created()
        case .watching:
            nil
        }
    }
    
}

extension WalletDisplayCategory {
    
    typealias CategorizedWalletDigests = OrderedDictionary<WalletDisplayCategory, [WalletDigest]>
    
    static func categorize(digests: [WalletDigest]) -> CategorizedWalletDigests {
        // Empty arrays for category ordering
        var results: CategorizedWalletDigests = [
            .all: digests.filter { digest in
                switch digest.wallet {
                case .privacy:
                    true
                case .common(let wallet):
                    wallet.category.knownCase != .watchAddress
                case .safe:
                    false
                }
            },
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
                case .none:
                        .none
                }
            case .safe:
                    .safe
            }
            if let category {
                var wallets = results[category] ?? []
                wallets.append(digest)
                results[category] = wallets
            }
        }
        for key in results.keys {
            results[key]?.sort { one, another in
                switch (one.wallet, another.wallet) {
                case (.privacy, _):
                    true
                case (_, .privacy):
                    false
                default:
                    one.usdBalanceSum > another.usdBalanceSum
                }
            }
        }
        return results
    }
    
}
