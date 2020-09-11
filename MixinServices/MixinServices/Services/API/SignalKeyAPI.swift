import Foundation
import Alamofire

public class SignalKeyAPI : MixinAPI {
    
    private enum Path {
        static let signal = "/signal/keys"
        static let signalKeyCount = "/signal/keys/count"
    }
    
    public static func pushSignalKeys(key: SignalKeyRequest) -> MixinAPI.Result<Empty> {
        return request(method: .post, path: Path.signal, parameters: key)
    }
    
    public static func getSignalKeyCount() -> MixinAPI.Result<SignalKeyCount> {
        return request(method: .get, path: Path.signalKeyCount)
    }
    
}
