import MixinServices
import Alamofire

public final class ReferralAPI: MixinAPI {
    
    public static func bindReferral(
        code: String,
        completion: @escaping (MixinAPI.Result<Empty>) -> Void
    ) {
        request(
            method: .post,
            path: "/referral/bind",
            parameters: ["code": code],
            completion: completion
        )
    }
    
}
