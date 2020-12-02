import Foundation
import GRDB

public protocol MixinFetchableRecord: FetchableRecord {
    
}

extension MixinFetchableRecord {
    
    public static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy {
        .formatted(.iso8601Full)
    }
    
}
