import Foundation
import MixinServices
import Alamofire

enum RewardAPI {
    
    static func referral(
        completion: @escaping (MixinAPI.Result<Referral>) -> Void
    ) {
        RouteAPI.request(
            method: .get,
            path: "/referral",
            config: .rewards,
            completion: completion
        )
    }
    
    static func appBanners(
        chainIDs: Set<String>? = nil,
        completion: @escaping (MixinAPI.Result<[AppBanner]>) -> Void
    ) {
        var path = "/app-banners"
        var arguments: [String] = []
        chainIDs?.forEach { chainID in
            arguments.append("chain=\(chainID)")
        }
        if !arguments.isEmpty {
            path.append("?" + arguments.joined(separator: "&"))
        }
        RouteAPI.request(
            method: .get,
            path: path,
            config: .rewards,
            completion: completion
        )
    }
    
}
