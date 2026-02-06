import Foundation
import Alamofire
import MixinServices

fileprivate let inscriptionContentCache = URLCache(memoryCapacity: 1 * Int(bytesPerMegaByte),
                                                   diskCapacity: 10 * Int(bytesPerMegaByte))

fileprivate final class Cacher: CachedResponseHandler {
    
    func dataTask(
        _ task: URLSessionDataTask,
        willCacheResponse response: CachedURLResponse,
        completion: @escaping (CachedURLResponse?) -> Void
    ) {
        guard let httpResponse = response.response as? HTTPURLResponse else {
            completion(nil)
            return
        }
        if httpResponse.statusCode == 200 {
            completion(response)
        } else {
            completion(nil)
        }
    }
    
}

let InscriptionContentSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 10
    config.requestCachePolicy = .useProtocolCachePolicy
    config.urlCache = inscriptionContentCache
    let cacher = Cacher()
    let session = Alamofire.Session(configuration: config,
                                    cachedResponseHandler: cacher)
    return session
}()
