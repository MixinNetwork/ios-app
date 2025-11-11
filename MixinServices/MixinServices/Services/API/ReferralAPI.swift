import MixinServices
import Alamofire

public final class ReferralAPI: MixinAPI {
    
    public static func referralCodeInfo(
        code: String
    ) async throws -> ReferralCodeInfo {
        try await request(
            method: .get,
            path: "/referral/codes/\(code)/info",
        )
    }
    
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
