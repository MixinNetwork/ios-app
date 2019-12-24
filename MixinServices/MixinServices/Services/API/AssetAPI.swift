import Foundation
import Alamofire

public final class AssetAPI: BaseAPI {

    public static let shared = AssetAPI()

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

        static func snapshot(snapshotId: String) -> String {
            return "snapshots/\(snapshotId)"
        }
        static func snapshot(traceId: String) -> String {
            return "transfers/trace/\(traceId)"
        }

        static let transactions = "transactions"
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

    public func assets(completion: @escaping (APIResult<[Asset]>) -> Void) {
        request(method: .get, url: url.assets, completion: completion)
    }

    public func assets() -> APIResult<[Asset]> {
        return request(method: .get, url: url.assets)
    }

    public func asset(assetId: String, completion: @escaping (APIResult<Asset>) -> Void) {
        request(method: .get, url: url.assets(assetId: assetId), completion: completion)
    }

    public func asset(assetId: String) -> APIResult<Asset> {
        return request(method: .get, url: url.assets(assetId: assetId))
    }

    public func transactions(transactionRequest: RawTransactionRequest, pin: String, completion: @escaping (APIResult<Snapshot>) -> Void) {
        var transactionRequest = transactionRequest
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            transactionRequest.pin = encryptedPin
            self?.request(method: .post, url: url.transactions, parameters: transactionRequest.toParameters(), encoding: EncodableParameterEncoding<RawTransactionRequest>(), completion: completion)
        }
    }

    public func transfer(assetId: String, opponentId: String, amount: String, memo: String, pin: String, traceId: String, completion: @escaping (APIResult<Snapshot>) -> Void) {
        KeyUtil.aesEncrypt(pin: pin, completion: completion) { [weak self](encryptedPin) in
            let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "memo": memo, "pin": encryptedPin, "trace_id": traceId]
            self?.request(method: .post, url: url.transfers, parameters: param, completion: completion)
        }
    }

    public func payments(assetId: String, opponentId: String, amount: String, traceId: String, completion: @escaping (APIResult<PaymentResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "opponent_id": opponentId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, completion: completion)
    }

    public func payments(assetId: String, addressId: String, amount: String, traceId: String, completion: @escaping (APIResult<PaymentResponse>) -> Void) {
        let param: [String : Any] = ["asset_id": assetId, "address_id": addressId, "amount": amount, "trace_id": traceId]
        request(method: .post, url: url.payments, parameters: param, completion: completion)
    }
    
    public func snapshots(opponentId: String) -> APIResult<[Snapshot]> {
        return request(method: .get, url: url.snapshots(opponentId: opponentId))
    }

    public func snapshot(snapshotId: String) -> APIResult<Snapshot> {
        return request(method: .get, url: url.snapshot(snapshotId: snapshotId))
    }

    public func snapshot(traceId: String) -> APIResult<Snapshot> {
        return request(method: .get, url: url.snapshot(traceId: traceId))
    }
    
    public func snapshots(limit: Int, offset: String? = nil, assetId: String? = nil) -> APIResult<[Snapshot]> {
        assert(limit <= 500)
        return request(method: .get, url: url.snapshots(limit: limit, offset: offset, assetId: assetId))
    }
    
    public func fee(assetId: String, completion: @escaping (APIResult<Fee>) -> Void) {
        request(method: .get, url: url.fee(assetId: assetId), completion: completion)
    }

    public func pendingDeposits(assetId: String, destination: String, tag: String) -> APIResult<[PendingDeposit]> {
        return request(method: .get, url: url.pendingDeposits(assetId: assetId, destination: destination, tag: tag))
    }
    
    public func search(keyword: String) -> APIResult<[Asset]>  {
        guard let url = url.search(keyword: keyword) else {
            return .success([])
        }
        return request(method: .get, url: url)
    }
    
    public func topAssets() -> APIResult<[Asset]> {
        return request(method: .get, url: url.top)
    }
    
    public func fiats() -> APIResult<[FiatMoney]> {
        return request(method: .get, url: url.fiats)
    }
    
}
