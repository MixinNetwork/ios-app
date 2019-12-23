import Foundation

struct TransferLiveData: Codable {
    
    let width: Int
    let height: Int
    let thumbUrl: String
    let url: String
    
    enum CodingKeys: String, CodingKey {
        case width
        case height
        case thumbUrl = "thumb_url"
        case url
    }
    
}
