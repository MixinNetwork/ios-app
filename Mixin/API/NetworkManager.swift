import Foundation
import Alamofire

class NetworkManager {

    static let shared = NetworkManager()

    private let reachabilityManager = Alamofire.NetworkReachabilityManager()

    var isReachable: Bool {
        return reachabilityManager?.isReachable ?? false
    }

    func startListening() {
        reachabilityManager?.startListening()
    }

    deinit {
        reachabilityManager?.stopListening()
    }

}
