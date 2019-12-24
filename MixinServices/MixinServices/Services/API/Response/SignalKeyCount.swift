import Foundation

public struct SignalKeyCount: Codable {
    
    public let preKeyCount: Int
    
    enum CodingKeys: String, CodingKey {
        case preKeyCount = "one_time_pre_keys_count"
    }
    
}
