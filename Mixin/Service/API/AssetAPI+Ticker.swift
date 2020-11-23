import MixinServices

extension AssetAPI {
    
    static func ticker(asset: String, offset: String, completion: @escaping (MixinAPI.Result<TickerResponse>) -> Void) {
        request(method: .get, path: "/ticker?asset=\(asset)&offset=\(offset)", completion: completion)
    }
    
}
