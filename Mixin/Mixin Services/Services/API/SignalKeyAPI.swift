import Foundation
import Alamofire

public class SignalKeyAPI : BaseAPI {
    
    public static let shared = SignalKeyAPI()
    
    private enum url {
        static let signal = "signal/keys"
        static let signalKeyCount = "signal/keys/count"
    }
    
    public func pushSignalKeys(key: SignalKeyRequest) -> APIResult<EmptyResponse> {
        return request(method: .post, url: url.signal, parameters: key.toParameters(), encoding: EncodableParameterEncoding<SignalKeyRequest>())
    }
    
    public func getSignalKeyCount() -> APIResult<SignalKeyCount> {
        return request(method: .get, url: url.signalKeyCount)
    }
    
}
