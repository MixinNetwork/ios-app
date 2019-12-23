import UIKit
import MixinServices

class CallAPI: BaseAPI {
    
    static let shared = CallAPI()
    
    private enum url {
        static let turn = "turn"
    }
    
    func turn(completion: @escaping (APIResult<[TurnServer]>) -> Void) {
        request(method: .get, url: url.turn, completion: completion)
    }
    
}
