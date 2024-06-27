import Foundation
import Alamofire
import MixinServices

fileprivate let inscriptionContentCache = URLCache(memoryCapacity: 1 * Int(bytesPerMegaByte),
                                                   diskCapacity: 10 * Int(bytesPerMegaByte))

let InscriptionContentSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 10
    config.requestCachePolicy = .useProtocolCachePolicy
    config.urlCache = inscriptionContentCache
    return Alamofire.Session(configuration: config)
}()
