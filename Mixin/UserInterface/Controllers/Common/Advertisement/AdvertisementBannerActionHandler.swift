import UIKit
import MixinServices

enum AdvertisementBannerActionHandler {
    
    static func perform(
        _ action: AdvertisementBanner.Action,
        for banner: AppBanner,
        source: String,
    ) {
        let url: URL
        switch action {
        case .background:
            guard
                let action = banner.actionURL,
                let actionURL = URL(string: action)
            else {
                return
            }
            url = actionURL
        case .button(let index):
            guard
                let actions = banner.actions,
                actions.indices.contains(index),
                let actionURL = URL(string: actions[index].action)
            else {
                return
            }
            url = actionURL
        }
        if !UrlWindow.checkUrl(url: url) {
            UIApplication.shared.homeNavigationController?.pushWebViewController(
                context: .init(conversationID: "", initialURL: url)
            )
        }
        if !banner.trackingKey.isEmpty {
            reporter.report(
                eventName: banner.trackingKey,
                tags: ["source": source]
            )
        }
    }
    
    static func dismiss(_ banner: AppBanner) {
        AppGroupUserDefaults.Wallet.closedBannerIDs.append(banner.bannerID)
    }
    
}
