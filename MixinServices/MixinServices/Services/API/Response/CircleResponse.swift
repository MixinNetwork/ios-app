import Foundation

public class CircleResponse: Codable {
    
    public let type: String
    public let circleId: String
    public let name: String
    public let createdAt: String
    
    public enum CodingKeys: String, CodingKey {
        case type
        case circleId = "circle_id"
        case name
        case createdAt = "created_at"
    }
    
}
