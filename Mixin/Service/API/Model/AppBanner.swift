import Foundation
import MixinServices

struct AppBanner: Codable {
    
    enum CodingKeys: String, CodingKey {
        case bannerID = "banner_id"
        case iconURL = "icon_url"
        case title = "title"
        case description = "description"
        case actionURL = "action_url"
        case actions = "actions"
        case trackingKey = "tracking_key"
        case endAt = "end_at"
        case chains = "chains"
    }
    
    let bannerID: String
    let iconURL: String
    let title: String
    let description: String
    let actionURL: String?
    let actions: [Action]?
    let trackingKey: String
    let endAt: String
    let chains: [String]
    
    func available(to chainIDs: Set<String>) -> Bool {
        if chains.isEmpty {
            true
        } else {
            !chainIDs.intersection(chains).isEmpty
        }
    }
    
}

extension AppBanner {
    
    struct Action: Codable {
        
        enum CodingKeys: String, CodingKey {
            case label = "label"
            case action = "action"
        }
        
        let label: String
        let action: String
        
    }
    
}

extension AppBanner: Equatable {
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.bannerID == rhs.bannerID
    }
    
}

extension AppBanner: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bannerID)
    }
    
}

extension AppBanner {
    
    static func saveToCache(remoteBanners: [AppBanner]) {
        PropertiesDAO.shared.set(jsonObject: remoteBanners, forKey: .walletBanners)
    }
    
    // nil for all chains
    static func loadFromCache(chainIDs: Set<String>?) -> [AppBanner] {
        let closedBannerIDs = Set(AppGroupUserDefaults.Wallet.closedBannerIDs)
        return PropertiesDAO.shared.jsonObject(
            forKey: .walletBanners,
            type: [AppBanner].self
        )?.filter { banner in
            guard let endAt = DateFormatter.iso8601Full.date(from: banner.endAt) else {
                return false
            }
            let chainsMatch: Bool = if let chainIDs {
                banner.available(to: chainIDs)
            } else {
                true
            }
            return endAt.timeIntervalSinceNow > 0
            && !closedBannerIDs.contains(banner.bannerID)
            && chainsMatch
        } ?? []
    }
    
}
