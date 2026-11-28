import Foundation
import GRDB
import SQLite3

enum KeywordMatchingRank {
    
    static let dbFunction = DatabaseFunction(
        "keyword_match",
        argumentCount: 2,
        pure: true
    ) { values -> Int in
        switch (values[0].storage, values[1].storage) {
        case let (.string(text), .string(keyword)):
            evaluate(text: text, keyword: keyword)
        default:
            0
        }
    }
    
    static func evaluate(text: String, keyword: String) -> Int {
        let escaped = SQLEscaping.escape(keyword)
        let escapeCharacter = SQLEscaping.escapeCharacter.value
        if sqlite3_strlike(escaped, text, escapeCharacter) == 0 {
            return 3
        } else if sqlite3_strlike("\(escaped)%", text, escapeCharacter) == 0 {
            return 2
        } else if sqlite3_strlike("%\(escaped)%", text, escapeCharacter) == 0 {
            return 1
        } else {
            return 0
        }
    }
    
}
