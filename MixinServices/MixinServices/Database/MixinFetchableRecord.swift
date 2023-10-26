import Foundation
import GRDB

public protocol MixinFetchableRecord: FetchableRecord {
    
}

extension MixinFetchableRecord {
    
    public static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy {
        .custom { value in
            switch value.storage {
            case .string(let string):
                return ISO8601CompatibleDateFormatter.date(from: string)
            default:
                return nil
            }
        }
    }
    
}
