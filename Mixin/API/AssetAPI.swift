import Foundation
import Alamofire

final class AssetAPI: BaseAPI {

    static let shared = AssetAPI()

    private enum url {
        static func assets(assetId: String) -> String {
            return "assets/" + assetId
        }
        static let assets = "assets"

        static func snapshots(assetId: String) -> String {
            return "assets/\(assetId)/snapshots"
        }

        static let transfers = "transfers"
        static let payments = "payments"
        
        static func fee(assetId: String) -> String {
            return "assets/\(assetId)/fee"
        }
    }

    func assets(completion: @escaping (APIResult<[Asset]>) -> Void) {
        request(method: .get, url: url.assets, completion: completion)
    }

    func assets() -> Result<[Asset]> {
        return request(method: .get, url: url.assets)
    }

    func asset(assetId: String, completion: @escaping (APIResult<Asset>) -> Void) {
        request(method: .get, url: url.assets(assetId: assetId), completion: completion)
    }

    func asset(assetId: String) -> Result<Asset> {
        return request(method: .get, url: url.assets(assetId: assetId))
    }

    func transfer(assetId: String, counterUserId: String, amount: String, memo: String, pin: String, traceId: String, completion: @escaping (APIResult<Snapshot>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            let param: [String : Any] = ["asset_id": assetId, "counter_user_id": counterUserId, "amount": amount, "memo": memo, "pin": encryptedPin, "trace_id": traceId]
            self?.request(method: .post, url: url.transfers, parameters: param, completion: completion)
        }
    }

    func payments(assetId: String, counterUserId: String, amount: String, traceId: String, completion: @escaping (APIResult<PaymentResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "counter_user_id": counterUserId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, completion: completion)
    }

    func snapshots(assetId: String, completion: @escaping (APIResult<[Snapshot]>) -> Void) {
        request(method: .get, url: url.snapshots(assetId: assetId), completion: completion)
    }

    func snapshots(assetId: String) -> Result<[Snapshot]> {
        return request(method: .get, url: url.snapshots(assetId: assetId))
    }
    
    func fee(assetId: String, completion: @escaping (APIResult<Fee>) -> Void) {
        request(method: .get, url: url.fee(assetId: assetId), completion: completion)
    }
    
}
