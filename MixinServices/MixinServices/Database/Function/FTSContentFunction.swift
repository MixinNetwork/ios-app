import Foundation
import GRDB

public func ftsContent(messageId: String, category: String, content: String?, name: String?, descendants: [TranscriptMessage]? = nil) -> String? {
    guard let category = MessageCategory(rawValue: category) else {
        return nil
    }
    switch category {
    case .PLAIN_DATA, .SIGNAL_DATA:
        return name
    case .SIGNAL_TEXT, .PLAIN_TEXT, .SIGNAL_POST, .PLAIN_POST:
        return content
    case .SIGNAL_TRANSCRIPT:
        let descendants = descendants ?? TranscriptMessageDAO.shared.descendantMessages(with: messageId)
        let ftsContents: [String] = descendants.compactMap { descendant in
            if descendant.category == .transcript {
                return nil
            } else {
                return ftsContent(messageId: descendant.messageId,
                                  category: descendant.category.rawValue,
                                  content: descendant.content,
                                  name: descendant.mediaName)
            }
        }
        return ftsContents.joined(separator: " ")
    default:
        return nil
    }
}

extension DatabaseFunction {
    
    static let ftsContent = DatabaseFunction("fts_content", argumentCount: 4, pure: true) { (values) -> String? in
        guard
            values.count == 4,
            let messageId = values[0].storage.value as? String,
            let category = values[1].storage.value as? String
        else {
            return nil
        }
        let content = values[2].storage.value as? String
        let name = values[3].storage.value as? String
        return MixinServices.ftsContent(messageId: messageId,
                                        category: category,
                                        content: content,
                                        name: name,
                                        descendants: nil)
    }
    
}
