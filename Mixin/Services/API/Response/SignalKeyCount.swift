import Foundation

public struct SignalKeyCount: Codable {
    
    let preKeyCount: Int
    
    enum CodingKeys: String, CodingKey {
        case preKeyCount = "one_time_pre_keys_count"
    }
    
}
