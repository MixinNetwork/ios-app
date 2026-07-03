import Foundation
import MixinServices
import Alamofire

enum CashAPI {
    
    static func account(
        completion: @escaping (MixinAPI.Result<CashAccount>) -> Void
    ) {
        RouteAPI.request(
            method: .get,
            path: "/account",
            config: .cash,
            completion: completion
        )
    }
    
}
