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
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<[AppBanner]>) -> Void,
    ) {
        RouteAPI.request(
            method: .get,
            path: "/app-banners",
            config: .rewards,
            queue: queue,
            completion: completion,
        )
    }
    
}
