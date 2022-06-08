import Foundation
import GRDB

public final class DeleteConversationAttachmentWork: Work {
    
    public struct Attachment: Codable, TableRecord, FetchableRecord {
        
        public static let databaseTableName = Message.databaseTableName
        
        let url: String
        let category: String
        
        public init(row: Row) {
            url = row["media_url"]
            category = row["category"]
        }
        
    }
    
    private let batchLimit = 50
    
    private var attachments: [Attachment]
    private var transcriptMessageIds: [String]
    
    public init(id: String = UUID().uuidString.lowercased(), attachments: [Attachment], transcriptMessageIds: [String]) {
        self.attachments = attachments
        self.transcriptMessageIds = transcriptMessageIds
        super.init(id: id, state: .ready)
    }
    
    public override func main() throws {
        Logger.general.debug(category: "DeleteConversationAttachmentWork", message: "[\(id)] Delete \(attachments.count) attachments, \(transcriptMessageIds.count) transcripts")
        if !attachments.isEmpty {
            repeat {
                let items = attachments.suffix(batchLimit)
                for item in items {
                    AttachmentContainer.removeMediaFiles(mediaUrl: item.url, category: item.category)
                }
                attachments.removeLast(items.count)
                updatePersistedContext()
                Logger.general.debug(category: "DeleteConversationAttachmentWork", message: "[\(id)] Updated with \(attachments.count) attachments, \(transcriptMessageIds.count) transcripts")
            } while !attachments.isEmpty
        }
        if !transcriptMessageIds.isEmpty {
            repeat {
                let ids = transcriptMessageIds.suffix(batchLimit)
                ids.forEach(AttachmentContainer.removeAll(transcriptId:))
                transcriptMessageIds.removeLast(ids.count)
                updatePersistedContext()
                Logger.general.debug(category: "DeleteConversationAttachmentWork", message: "[\(id)] Updated with \(attachments.count) attachments, \(transcriptMessageIds.count) transcripts")
            } while !transcriptMessageIds.isEmpty
        }
    }
    
}

extension DeleteConversationAttachmentWork: PersistableWork {
    
    private struct Context: Codable {
        let attachments: [Attachment]
        let transcriptMessageIds: [String]
    }
    
    public static let typeIdentifier = "delete_conversation_attachment"
    
    public var context: Data? {
        let context = Context(attachments: attachments, transcriptMessageIds: transcriptMessageIds)
        return try? JSONEncoder.default.encode(context)
    }
    
    public var priority: PersistedWork.Priority {
        .low
    }
    
    public convenience init(id: String, context: Data?) throws {
        guard
            let context = context,
            let context = try? JSONDecoder.default.decode(Context.self, from: context)
        else {
            throw PersistableWorkError.invalidContext
        }
        self.init(id: id, attachments: context.attachments, transcriptMessageIds: context.transcriptMessageIds)
    }
    
}
