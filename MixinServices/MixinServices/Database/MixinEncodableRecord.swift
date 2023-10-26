import Foundation
import GRDB

protocol MixinEncodableRecord: EncodableRecord {

}

extension MixinEncodableRecord {
    
    public static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy {
        .custom { date in
            ISO8601CompatibleDateFormatter.string(from: date)
        }
    }
    
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy {
        .lowercaseString
    }
    
}
