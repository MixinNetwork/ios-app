import Foundation

struct StreamId: RawRepresentable {
    
    private static let separator = "~"
    
    let userId: String
    let sessionId: String
    
    let rawValue: String
    
    init?(rawValue: String) {
        let components = rawValue.components(separatedBy: Self.separator)
        guard components.count == 2 else {
            return nil
        }
        self.userId = components[0]
        self.sessionId = components[1]
        self.rawValue = rawValue
    }
    
    init(userId: String, sessionId: String) {
        self.userId = userId
        self.sessionId = sessionId
        self.rawValue = userId + Self.separator + sessionId
    }
    
}
