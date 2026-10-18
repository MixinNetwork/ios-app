import Foundation

enum AdvertisementBanner: Equatable, Hashable {
    
    enum EmbeddedBanner: Hashable {
        case addWallet
    }
    
    enum Action {
        case background
        case button(Int)
    }
    
    case embedded(EmbeddedBanner)
    case remote(AppBanner)
    
}
