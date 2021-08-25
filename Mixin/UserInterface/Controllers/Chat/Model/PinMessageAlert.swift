import UIKit

struct PinMessageAlert: Codable {
    
    let messageId: String
    let preview: String
    
}

extension PinMessageAlert {
    
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
