import Foundation

enum WatchlistSubCategory: String, CaseIterable {
    
    case crypto
    case perps
    
    var displayTitle: String {
        switch self {
        case .crypto:
            R.string.localizable.crypto()
        case .perps:
            R.string.localizable.perpetual()
        }
    }
    
}
