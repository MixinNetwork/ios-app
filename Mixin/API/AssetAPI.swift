import Foundation
import Alamofire

final class AssetAPI: BaseAPI {

    static let shared = AssetAPI()

    private enum url {

        static let assets = "assets"
        static func assets(assetId: String) -> String {
            return "assets/" + assetId
        }
        static func fee(assetId: String) -> String {
            return "assets/\(assetId)/fee"
        }

        static let snapshots = "snapshots"
        static func snapshots(assetId: String) -> String {
            return "assets/\(assetId)/snapshots"
        }

        static let transfers = "transfers"
        static let payments = "payments"
    }

    func assets(completion: @escaping (APIResult<[Asset]>) -> Void) {
        request(method: .get, url: url.assets, completion: completion)
    }

    func assets() -> APIResult<[Asset]> {
        return request(method: .get, url: url.assets)
    }

    func asset(assetId: String, completion: @escaping (APIResult<Asset>) -> Void) {
        request(method: .get, url: url.assets(assetId: assetId), completion: completion)
    }

    func asset(assetId: String) -> APIResult<Asset> {
        return request(method: .get, url: url.assets(assetId: assetId))
    }

    func transfer(assetId: String, opponentId: String, amount: String, memo: String, pin: String, traceId: String, completion: @escaping (APIResult<Snapshot>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "memo": memo, "pin": encryptedPin, "trace_id": traceId]
            self?.request(method: .post, url: url.transfers, parameters: param, toastError: false, completion: completion)
        }
    }

    func payments(assetId: String, opponentId: String, amount: String, traceId: String, completion: @escaping (APIResult<PaymentResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, toastError: false, completion: completion)
    }

    func snapshots(completion: @escaping (APIResult<[Snapshot]>) -> Void) {
        request(method: .get, url: url.snapshots, completion: completion)
    }

    func snapshots(assetId: String, completion: @escaping (APIResult<[Snapshot]>) -> Void) {
        request(method: .get, url: url.snapshots(assetId: assetId), completion: completion)
    }

    func snapshots(assetId: String) -> APIResult<[Snapshot]> {
        return request(method: .get, url: url.snapshots(assetId: assetId))
    }
    
    func fee(assetId: String, completion: @escaping (APIResult<Fee>) -> Void) {
        request(method: .get, url: url.fee(assetId: assetId), completion: completion)
    }
    
}
