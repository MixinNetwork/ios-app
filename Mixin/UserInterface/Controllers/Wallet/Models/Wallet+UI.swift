import Foundation
import MixinServices

extension Wallet {
    
    var localizedName: String {
        switch self {
        case .privacy:
            R.string.localizable.privacy_wallet()
        case .common(let wallet):
            wallet.name
        case .safe(let wallet):
            wallet.name
        }
    }
    
}

extension Wallet {
    
    private var createdAt: String? {
        switch self {
        case .privacy:
            nil
        case .common(let wallet):
            wallet.createdAt
        case .safe(let wallet):
            wallet.createdAt
        }
    }
    
    func compare(_ other: Wallet) -> ComparisonResult {
        let oneCreatedAt = self.createdAt
        let otherCreatedAt = other.createdAt
        return switch (oneCreatedAt, otherCreatedAt) {
        case (.none, .some):
                .orderedAscending
        case (.none, .none):
                .orderedSame
        case (.some, .none):
                .orderedDescending
        case let (.some(one), .some(another)):
            one.compare(another)
        }
    }
    
}

extension Wallet {
    
    enum Tag {
        case plain(String)
        case warning(String)
        case role(String)
    }
    
}
