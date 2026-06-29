import Foundation
import MixinServices

enum WalletBanner: Equatable, Hashable {
    
    enum EmbeddedBanner: Hashable {
        case addWallet
    }
    
    case embedded(EmbeddedBanner)
    case remote(AppBanner)
    
    func invokeRemoteActionURL() {
        switch self {
        case .embedded:
            break
        case .remote(let banner):
            if let action = banner.actionURL,
               let url = URL(string: action)
            {
                _ = UrlWindow.checkUrl(url: url)
            }
            if !banner.trackingKey.isEmpty {
                reporter.report(
                    eventName: banner.trackingKey,
                    tags: ["source": "wallet_home_ad_banner_background"]
                )
            }
        }
    }
    
}
