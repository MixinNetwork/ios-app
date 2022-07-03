import Foundation
import GRDB
import MixinServices

public protocol DeletableMessage {
    var messageId: String { get }
    var conversationId: String { get }
    var category: String { get }
    var mediaUrl: String? { get }
}

extension Message: DeletableMessage {
    
}

extension MessageItem: DeletableMessage {
    
}

public final class DeleteMessageAttachmentWork: Work {
    
    private enum Attachment: Codable {
        case media(category: String, filename: String)
        case transcript
    }
    
    public static let willDeleteNotification = Notification.Name("one.mixin.services.DeleteMessageAttachmentWork.willDelete")
    public static let messageIdUserInfoKey = "mid"
    public static let capableMessageCategories: Set<String> = [
        MessageCategory.SIGNAL_IMAGE.rawValue, MessageCategory.PLAIN_IMAGE.rawValue, MessageCategory.ENCRYPTED_IMAGE.rawValue,
        MessageCategory.SIGNAL_VIDEO.rawValue, MessageCategory.PLAIN_VIDEO.rawValue, MessageCategory.ENCRYPTED_VIDEO.rawValue,
        MessageCategory.SIGNAL_AUDIO.rawValue, MessageCategory.PLAIN_AUDIO.rawValue, MessageCategory.ENCRYPTED_AUDIO.rawValue,
        MessageCategory.SIGNAL_DATA.rawValue, MessageCategory.PLAIN_DATA.rawValue, MessageCategory.ENCRYPTED_DATA.rawValue,
        MessageCategory.SIGNAL_TRANSCRIPT.rawValue, MessageCategory.PLAIN_TRANSCRIPT.rawValue, MessageCategory.ENCRYPTED_TRANSCRIPT.rawValue,
    ]
    
    private let messageId: String
    private let conversationId: String
    private let attachment: Attachment?
    
    public convenience init(message: DeletableMessage) {
        let attachment: Attachment?
        if MessageCategory.allMediaCategoriesString.contains(message.category), let filename = message.mediaUrl {
            attachment = .media(category: message.category, filename: filename)
        } else if message.category.hasSuffix("_TRANSCRIPT") {
            attachment = .transcript
        } else {
            attachment = nil
        }
        self.init(messageId: message.messageId, conversationId: message.conversationId, attachment: attachment)
    }
    
    private init(messageId: String, conversationId: String, attachment: Attachment?) {
        self.messageId = messageId
        self.conversationId = conversationId
        self.attachment = attachment
        super.init(id: "delete-message-\(messageId)", state: .ready)
    }
    
    public override func main() throws {
        NotificationCenter.default.post(onMainThread: Self.willDeleteNotification,
                                        object: self,
                                        userInfo: [Self.messageIdUserInfoKey: messageId])
        switch attachment {
        case let .media(category, filename):
            AttachmentContainer.removeMediaFiles(mediaUrl: filename, category: category)
        case .transcript:
            let transcriptId = messageId
            let childMessageIds = TranscriptMessageDAO.shared.childrenMessageIds(transcriptId: transcriptId)
            let jobIds = childMessageIds.map { transcriptMessageId in
                AttachmentDownloadJob.jobId(transcriptId: transcriptId, messageId: transcriptMessageId)
            }
            for id in jobIds {
                ConcurrentJobQueue.shared.cancelJob(jobId: id)
            }
            AttachmentContainer.removeAll(transcriptId: transcriptId)
            TranscriptMessageDAO.shared.deleteTranscriptMessages(with: transcriptId)
        case .none:
            break
        }
    }
    
}

extension DeleteMessageAttachmentWork: PersistableWork {
    
    private struct Context: Codable {
        let messageId: String
        let conversationId: String
        let attachment: Attachment?
    }
    
    public static let typeIdentifier: String = "delete_message_attachment"
    
    public var context: Data? {
        let context = Context(messageId: messageId,
                              conversationId: conversationId,
                              attachment: attachment)
        return try? JSONEncoder.default.encode(context)
    }
    
    public var priority: PersistedWork.Priority {
        .medium
    }
    
    public convenience init(id: String, context: Data?) throws {
        guard
            let context = context,
            let context = try? JSONDecoder.default.decode(Context.self, from: context)
        else {
            throw PersistableWorkError.invalidContext
        }
        self.init(messageId: context.messageId,
                  conversationId: context.conversationId,
                  attachment: context.attachment)
    }
    
}
