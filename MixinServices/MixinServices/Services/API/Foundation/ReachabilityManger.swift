import Foundation
import Alamofire

public class ReachabilityManger {
    
    public static let shared = ReachabilityManger()
    public static let reachabilityDidChangeNotification = NSNotification.Name("one.mixin.services.ReachabilityManger.ReachabilityDidChange")
    
    private let manager = NetworkReachabilityManager()
    
    public var isReachable: Bool {
        manager?.isReachable ?? false
    }
    
    public var isReachableOnEthernetOrWiFi: Bool {
        manager?.isReachableOnEthernetOrWiFi ?? false
    }
    
    public init() {
        manager?.startListening(onQueue: .main, onUpdatePerforming: { (status) in
            NotificationCenter.default.post(name: Self.reachabilityDidChangeNotification, object: nil)
        })
    }
    
    deinit {
        manager?.stopListening()
    }
    
}
