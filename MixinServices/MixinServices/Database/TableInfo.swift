import Foundation
import GRDB

internal struct TableInfo: Decodable, MixinFetchableRecord {
    
    // There're more columns in table_info, but those
    // are omitted since we don't need them currently
    
    let name: String
    
}
