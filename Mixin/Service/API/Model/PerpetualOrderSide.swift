import Foundation

enum PerpetualOrderSide: String, Codable {
    
    case long
    case short
    
    var localizedName: String {
        switch self {
        case .long:
            R.string.localizable.long()
        case .short:
            R.string.localizable.short()
        }
    }
    
}
