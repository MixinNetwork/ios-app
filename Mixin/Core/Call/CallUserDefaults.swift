import Foundation
import WebRTC

class CallUserDefaults {
    
    static let shared = CallUserDefaults()
    
    private let session = UserDefaults(suiteName: SuiteName.call)
    private let invalidationHours: Double = 23
    
    private lazy var decoder = JSONDecoder()
    private lazy var encoder = JSONEncoder()
    
    private enum Key {
        static let servers = "turn_servers"
        static let date = "turn_servers_fetching_date"
    }
    
    var servers: [TurnServer]? {
        get {
            guard let date = session?.object(forKey: Key.date) as? Date, abs(date.timeIntervalSinceNow) < invalidationHours * 60 * 60, let jsonData = session?.data(forKey: Key.servers) else {
                return nil
            }
            return try? decoder.decode([TurnServer].self, from: jsonData)
        }
        set {
            if let newValue = newValue, let jsonData = try? encoder.encode(newValue) {
                session?.set(Date(), forKey: Key.date)
                session?.set(jsonData, forKey: Key.servers)
            } else {
                clear()
            }
        }
    }
    
    func clear() {
        session?.removeObject(forKey: Key.date)
        session?.removeObject(forKey: Key.servers)
    }
    
}
