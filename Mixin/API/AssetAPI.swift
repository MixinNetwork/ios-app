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

        static func snapshots(limit: Int, offset: String? = nil, assetId: String? = nil) -> String {
            var url = "snapshots?limit=\(limit)"
            if let offset = offset {
                url += "&offset=\(offset)"
            }
            if let assetId = assetId {
                url += "&asset=\(assetId)"
            }
            return url
        }
        static func snapshots(opponentId: String) -> String {
            return "mutual_snapshots/\(opponentId)"
        }
        
        static let transfers = "transfers"
        static let payments = "payments"

        static func pendingDeposits(assetId: String, destination: String, tag: String) -> String {
            return "external/transactions?asset=\(assetId)&destination=\(destination)&tag=\(tag)"
        }
        
        static func search(keyword: String) -> String? {
            return "network/assets/search/\(keyword)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        static let top = "network/assets/top"
        
        static let fiats = "fiats"
        
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
            self?.request(method: .post, url: url.transfers, parameters: param, completion: completion)
        }
    }

    func payments(assetId: String, opponentId: String, amount: String, traceId: String, completion: @escaping (APIResult<PaymentResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, completion: completion)
    }

    func payments(assetId: String, addressId: String, amount: String, traceId: String, completion: @escaping (APIResult<PaymentResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "address_id": addressId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, completion: completion)
    }
    
    func snapshots(opponentId: String) -> APIResult<[Snapshot]> {
        return request(method: .get, url: url.snapshots(opponentId: opponentId))
    }
    
    func snapshots(limit: Int, offset: String? = nil, assetId: String? = nil) -> APIResult<[Snapshot]> {
        assert(limit <= 500)
        return request(method: .get, url: url.snapshots(limit: limit, offset: offset, assetId: assetId))
    }
    
    func fee(assetId: String, completion: @escaping (APIResult<Fee>) -> Void) {
        request(method: .get, url: url.fee(assetId: assetId), completion: completion)
    }

    func pendingDeposits(assetId: String, destination: String, tag: String) -> APIResult<[PendingDeposit]> {
        return request(method: .get, url: url.pendingDeposits(assetId: assetId, destination: destination, tag: tag))
    }
    
    func search(keyword: String) -> APIResult<[Asset]>  {
        guard let url = url.search(keyword: keyword) else {
            return .success([])
        }
        return request(method: .get, url: url)
    }
    
    func topAssets() -> APIResult<[Asset]> {
        return request(method: .get, url: url.top)
    }
    
    func fiats() -> APIResult<[FiatMoney]> {
        return request(method: .get, url: url.fiats)
    }
    
}
