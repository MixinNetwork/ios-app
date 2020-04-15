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
    public func snapshots(limit: Int, offset: String? = nil, assetId: String? = nil, opponentId: String? = nil) -> APIResult<[Snapshot]> {
        assert(limit <= 500)
        return request(method: .get, url: url.snapshots(limit: limit, offset: offset, assetId: assetId, opponentId: opponentId))
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
    
    public func topAssets(completion: @escaping (APIResult<[Asset]>) -> Void) {
        request(method: .get, url: url.top, completion: completion)
    }
    
    public func fiats() -> APIResult<[FiatMoney]> {
        return request(method: .get, url: url.fiats)
    }
    
}
