import UIKit

struct DisplayedPinMessage: Codable {
    
    let messageId: String
    let pinnedMessageId: String
    
}

extension DisplayedPinMessage {
    
    func toData() -> Data? {
        do {
            let data = try JSONEncoder.default.encode(self)
            return data
        } catch {
            return nil
        }
    }
    
    static func fromData(_ data: Data) -> Self? {
        do {
            let `self` = try JSONDecoder.default.decode(self, from: data)
            return `self`
        } catch {
            return nil
        }
    }
    
}
