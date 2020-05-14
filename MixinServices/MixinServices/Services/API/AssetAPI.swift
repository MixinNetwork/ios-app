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

        static func snapshots(limit: Int, offset: String? = nil, assetId: String? = nil, opponentId: String? = nil) -> String {
            var url = "snapshots?limit=\(limit)"
            if let offset = offset {
                url += "&offset=\(offset)"
            }
            if let assetId = assetId {
                url += "&asset=\(assetId)"
            }
            if let opponentId = opponentId {
                url += "&opponent=\(opponentId)"
            }
            return url
        }
        static func pendingDeposits(assetId: String, destination: String, tag: String) -> String {
            return "external/transactions?asset=\(assetId)&destination=\(destination)&tag=\(tag)"
        }
        
        static func search(keyword: String) -> String? {
            return "network/assets/search/\(keyword)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        static let top = "network/assets/top"
        
        static let fiats = "fiats"
    }

    public func assets(completion: @escaping (BaseAPI.Result<[Asset]>) -> Void) {
        request(method: .get, url: url.assets, completion: completion)
    }

    public func assets() -> BaseAPI.Result<[Asset]> {
        return request(method: .get, url: url.assets)
    }

    public func asset(assetId: String, completion: @escaping (BaseAPI.Result<Asset>) -> Void) {
        request(method: .get, url: url.assets(assetId: assetId), completion: completion)
    }

    public func asset(assetId: String) -> BaseAPI.Result<Asset> {
        return request(method: .get, url: url.assets(assetId: assetId))
    }
    public func snapshots(limit: Int, offset: String? = nil, assetId: String? = nil, opponentId: String? = nil) -> BaseAPI.Result<[Snapshot]> {
        assert(limit <= 500)
        return request(method: .get, url: url.snapshots(limit: limit, offset: offset, assetId: assetId, opponentId: opponentId))
    }

    public func snapshots(limit: Int, assetId: String, completion: @escaping (BaseAPI.Result<[Snapshot]>) -> Void) {
        request(method: .get, url: url.snapshots(limit: limit, offset: nil, assetId: assetId, opponentId: nil), completion: completion)
    }
    
    public func fee(assetId: String, completion: @escaping (BaseAPI.Result<Fee>) -> Void) {
        request(method: .get, url: url.fee(assetId: assetId), completion: completion)
    }

    public func pendingDeposits(assetId: String, destination: String, tag: String, completion: @escaping (BaseAPI.Result<[PendingDeposit]>) -> Void) {
        request(method: .get, url: url.pendingDeposits(assetId: assetId, destination: destination, tag: tag), completion: completion)
    }
    
    public func search(keyword: String) -> BaseAPI.Result<[Asset]>  {
        guard let url = url.search(keyword: keyword) else {
            return .success([])
        }
        return request(method: .get, url: url)
    }
    
    public func topAssets(completion: @escaping (BaseAPI.Result<[Asset]>) -> Void) {
        request(method: .get, url: url.top, completion: completion)
    }
    
    public func fiats(completion: @escaping (BaseAPI.Result<[FiatMoney]>) -> Void) {
        request(method: .get, url: url.fiats, completion: completion)
    }
    
}
