import Foundation
import GRDB

internal struct TableInfo {
    
    // There're more columns in table_info, but those
    // are omitted since we don't need them currently
    
    let name: String
    
}

extension TableInfo: Decodable, MixinFetchableRecord {
    
    internal enum CodingKeys: String, CodingKey {
        case name
    }
    
}
