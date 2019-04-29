import Foundation

struct Keyword {
    
    let raw: String
    let trimmed: String
    
    init?(raw: String?) {
        guard let raw = raw else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else {
            return nil
        }
        self.raw = raw
        self.trimmed = trimmed
    }
    
}

extension Keyword: Equatable {
    
    static func == (lhs: Keyword, rhs: Keyword) -> Bool {
        return lhs.trimmed == rhs.trimmed
    }
    
}
