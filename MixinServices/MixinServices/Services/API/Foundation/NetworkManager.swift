import Foundation
import Alamofire

public class NetworkManager {
    
    public static let shared = NetworkManager()
    
    private let reachabilityManager = Alamofire.NetworkReachabilityManager()

    private init() {
        reachabilityManager?.startListening(onQueue: .main, onUpdatePerforming: { (_) in
            NotificationCenter.default.post(name: .NetworkDidChange, object: nil)
        })
    }
    
    public var isReachable: Bool {
        return reachabilityManager?.isReachable ?? false
    }
    
    public var isReachableOnWiFi: Bool {
        return reachabilityManager?.isReachableOnEthernetOrWiFi ?? false
    }
    
    deinit {
        reachabilityManager?.stopListening()
    }
    
}
