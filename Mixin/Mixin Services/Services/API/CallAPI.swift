import UIKit

public class CallAPI: BaseAPI {
    
    public static let shared = CallAPI()
    
    private enum url {
        static let turn = "turn"
    }
    
    public func turn(completion: @escaping (APIResult<[TurnServer]>) -> Void) {
        request(method: .get, url: url.turn, completion: completion)
    }
    
}
