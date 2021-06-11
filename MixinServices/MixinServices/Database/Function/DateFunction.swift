import Foundation
import GRDB

func unixTimeInMilliseconds(iso8601: String) -> String {
    let time = iso8601.toUTCDate().timeIntervalSince1970 * millisecondsPerSecond
    return String(Int(time))
}

extension DatabaseFunction {
    
    static let iso8601ToUnixTime = DatabaseFunction("i8tout", argumentCount: 1, pure: true) { (values) -> String? in
        switch values.first?.storage {
        case let .string(text):
            return unixTimeInMilliseconds(iso8601: text)
        default:
            return nil
        }
    }
    
}
