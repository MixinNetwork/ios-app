import Foundation
import MixinServices
import Alamofire

enum EarnAPI {
    
    static func productions(
        queue: DispatchQueue = .main,
        completion: @escaping (MixinAPI.Result<[EarnProduct]>) -> Void
    ) {
        RouteAPI.request(
            method: .get,
            path: "/productions",
            config: .earn,
            queue: queue,
            completion: completion
        )
    }
    
}
