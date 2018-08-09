import Foundation
import Alamofire

class SignalKeyAPI : BaseAPI {
    static let shared = SignalKeyAPI()
    private enum url {
        static let signal = "signal/keys"
        static let signalKeyCount = "signal/keys/count"
    }

    func pushSignalKeys(key: SignalKeyRequest) -> APIResult<EmptyResponse> {
        return request(method: .post, url: url.signal, parameters: key.toParameters(), encoding: EncodableParameterEncoding<SignalKeyRequest>())
    }

    func getSignalKeyCount() -> APIResult<SignalKeyCount> {
        return request(method: .get, url: url.signalKeyCount)
    }
}
