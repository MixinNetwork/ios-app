import Foundation

enum WatchlistSubCategory: String, CaseIterable {
    
    case crypto
    case perps
    
    var subCategoryDisplay: MarketSubCategoryDisplay {
        switch self {
        case .crypto:
                .text(R.string.localizable.crypto())
        case .perps:
                .text(R.string.localizable.perpetual())
        }
    }
    
}
