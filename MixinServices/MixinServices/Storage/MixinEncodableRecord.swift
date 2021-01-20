import Foundation
import GRDB

protocol MixinEncodableRecord: EncodableRecord {

}

extension MixinEncodableRecord {
    
    public static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy {
        .formatted(.iso8601Full)
    }
    
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy {
        .string
    }
    
}
