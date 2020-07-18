import Foundation

public struct KrakenPublishResponse: Codable {
    
    public let trackId: String
    public let jsep: String
    
    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case jsep
    }
    
}
