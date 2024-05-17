import MixinServices

extension ExternalAPI {
    
    static func dapps(queue: DispatchQueue, completion: @escaping (MixinAPI.Result<[Web3ChainUpdate]>) -> Void) {
        request(method: .get, path: "/external/dapps", queue: queue, completion: completion)
    }
    
}
