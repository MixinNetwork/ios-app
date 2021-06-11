import Foundation
import GRDB

public func ftsContent(messageId: String, category: String, content: String?, name: String?, children: [TranscriptMessage]? = nil) -> String? {
    guard let category = MessageCategory(rawValue: category) else {
        return nil
    }
    switch category {
    case .PLAIN_DATA, .SIGNAL_DATA:
        return name
    case .SIGNAL_TEXT, .PLAIN_TEXT, .SIGNAL_POST, .PLAIN_POST:
        return content
    case .SIGNAL_TRANSCRIPT:
        let children = children ?? TranscriptMessageDAO.shared.childMessages(with: messageId)
        let ftsContents: [String] = children.compactMap { child in
            ftsContent(messageId: child.messageId,
                       category: child.category.rawValue,
                       content: child.content,
                       name: child.mediaName)
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
                                        children: nil)
    }
    
}
