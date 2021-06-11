import Foundation
import GRDB

public func uuidTokenString(uuidString: String) -> String {
    uuidString.withCString { (ptr) -> String in
        String(bytesNoCopy: utot(ptr),
               length: 36,
               encoding: .utf8,
               freeWhenDone: true)!
    }
}

public func uuidString(uuidTokenString: String) -> String {
    uuidTokenString.withCString { (ptr) -> String in
        String(bytesNoCopy: ttou(ptr),
               length: 36,
               encoding: .utf8,
               freeWhenDone: true)!
    }
}

extension DatabaseFunction {
    
    static let uuidToToken = DatabaseFunction("utot", argumentCount: 1, pure: true) { (values) -> String? in
        switch values.first?.storage {
        case let .string(text):
            return uuidTokenString(uuidString: text)
        default:
            return nil
        }
    }
    
    static let tokenToUUID = DatabaseFunction("ttou", argumentCount: 1, pure: true) { (values) -> String? in
        switch values.first?.storage {
        case let .string(text):
            return uuidString(uuidTokenString: text)
        default:
            return nil
        }
    }
    
}
