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
    
}
