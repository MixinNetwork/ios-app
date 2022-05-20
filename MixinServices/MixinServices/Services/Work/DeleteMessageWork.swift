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

/*
 Straight execute
 ┌───────────────┐  ┌───────────┐Completed┌────────────────┐
 │Init(preparing)├─►│Persistence├────────►│Delete DB Record│
 └───────────────┘  └───────────┘         └────┬───────────┘
                                               │
                 ┌───────────┐Execute┌─────┐   │Completed
                 │Delete file│◄──────┤Ready│◄──┘
                 └───────────┘       └─────┘
 
 Awake from persistence
 ┌────────────┐  ┌────────────────┐Completed┌───────────┐
 │Awake(ready)├─►│Delete DB Record├────────►│Delete file│
 └────────────┘  └────────────────┘         └───────────┘
 */

public final class DeleteMessageWork: Work {
    
    public enum Attachment: Codable {
        case media(category: String, filename: String)
        case transcript
    }
    
    public enum Error: Swift.Error {
        case invalidContext
    }
    
    public static let willDeleteNotification = Notification.Name("one.mixin.services.DeleteMessageWork.willDelete")
    public static let messageIdUserInfoKey = "msg"
    
    let messageId: String
    let conversationId: String
    let attachment: Attachment?
    
    @Synchronized(value: false)
    private var hasDatabaseRecordDeleted: Bool
    
    public convenience init(message: DeletableMessage) {
        let attachment: Attachment?
        if ["_IMAGE", "_DATA", "_AUDIO", "_VIDEO"].contains(where: message.category.hasSuffix), let filename = message.mediaUrl {
            attachment = .media(category: message.category, filename: filename)
        } else if message.category.hasSuffix("_TRANSCRIPT") {
            attachment = .transcript
        } else {
            attachment = nil
        }
        self.init(messageId: message.messageId, conversationId: message.conversationId, attachment: attachment, state: .preparing)
    }
    
    private init(messageId: String, conversationId: String, attachment: Attachment?, state: State) {
        self.messageId = messageId
        self.conversationId = conversationId
        self.attachment = attachment
        super.init(id: "delete-message-\(messageId)", state: state)
    }
    
    public override func start() {
        state = .executing
        if hasDatabaseRecordDeleted {
            deleteFile()
            state = .finished(.success)
        } else {
            MessageDAO.shared.delete(id: messageId, conversationId: conversationId) {
                Logger.general.debug(category: "DeleteMessageWork", message: "\(self.messageId) Message deleted from database")
                self.deleteFile()
                self.state = .finished(.success)
            }
        }
    }
    
    private func deleteFile() {
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

extension DeleteMessageWork: PersistableWork {
    
    private struct Context: Codable {
        let messageId: String
        let conversationId: String
        let attachment: Attachment?
    }
    
    public static let typeIdentifier: String = "delete_message"
    
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
            throw Error.invalidContext
        }
        self.init(messageId: context.messageId,
                  conversationId: context.conversationId,
                  attachment: context.attachment,
                  state: .ready)
    }
    
    public func persistenceDidComplete() {
        NotificationCenter.default.post(onMainThread: Self.willDeleteNotification,
                                        object: self,
                                        userInfo: [Self.messageIdUserInfoKey: messageId])
        MessageDAO.shared.delete(id: messageId, conversationId: conversationId) {
            self.state = .ready
        }
        hasDatabaseRecordDeleted = true
        Logger.general.debug(category: "DeleteMessageWork", message: "\(messageId) Message deleted from database")
    }
    
}
