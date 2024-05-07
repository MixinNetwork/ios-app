import MixinServices

extension ExternalAPI {
    
    static func dapps(completion: @escaping (MixinAPI.Result<[Web3ChainUpdate]>) -> Void) {
        request(method: .get, path: "/external/dapps", completion: completion)
    }
    
}
