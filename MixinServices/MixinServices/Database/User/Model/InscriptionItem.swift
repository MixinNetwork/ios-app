import Foundation
import GRDB

public final class InscriptionItem: Inscription {
    
    enum JoinedQueryCodingKeys: String, CodingKey {
        case collectionName = "collection_name"
        case collectionIconURL = "collection_icon_url"
    }
    
    public let collectionName: String?
    public let collectionIconURL: String?
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: JoinedQueryCodingKeys.self)
        
        self.collectionName = try? container.decodeIfPresent(String.self, forKey: .collectionName)
        self.collectionIconURL = try? container.decodeIfPresent(String.self, forKey: .collectionIconURL)
        
        try super.init(from: decoder)
    }
}
