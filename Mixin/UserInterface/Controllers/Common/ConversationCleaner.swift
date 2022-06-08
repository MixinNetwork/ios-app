import Foundation
import MixinServices
import GRDB

enum ConversationCleaner {
    
    public static let willCleanNotification = Notification.Name("one.mixin.messenger.ConversationCleaner.willClean")
    public static let conversationIdUserInfoKey = "cid"
    
    enum Intent {
        case delete
        case clear
    }
    
    static func clean(conversationId: String, intent: Intent, completion: (() -> Void)? = nil) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        NotificationCenter.default.post(name: Self.willCleanNotification,
                                        object: self,
                                        userInfo: [Self.conversationIdUserInfoKey: conversationId])
        DispatchQueue.global().async {
            UserDatabase.current.write { db in
                let categories = MessageCategory.allMediaCategoriesString.joined(separator: "', '")
                let sql = "SELECT media_url, category FROM messages WHERE conversation_id = ? AND category IN ('\(categories)') AND media_url IS NOT NULL"
                let attachments = try DeleteConversationAttachmentWork.Attachment.fetchAll(db, sql: sql, arguments: [conversationId])
                let transcriptMessageIds = try MessageDAO.shared.getTranscriptMessageIds(conversationId: conversationId, database: db)
                if !attachments.isEmpty || !transcriptMessageIds.isEmpty {
                    let work = DeleteConversationAttachmentWork(attachments: attachments, transcriptMessageIds: transcriptMessageIds)
                    WorkManager.general.addPersistableWork(work, alongsideTransactionWith: db)
                }
                
                try Message
                    .filter(Message.column(of: .conversationId) == conversationId)
                    .deleteAll(db)
                try MessageMention
                    .filter(MessageMention.column(of: .conversationId) == conversationId)
                    .deleteAll(db)
                
                switch intent {
                case .delete:
                    try Conversation
                        .filter(Conversation.column(of: .conversationId) == conversationId)
                        .deleteAll(db)
                    try Participant
                        .filter(Participant.column(of: .conversationId) == conversationId)
                        .deleteAll(db)
                    try ParticipantSession
                        .filter(ParticipantSession.column(of: .conversationId) == conversationId)
                        .deleteAll(db)
                case .clear:
                    try Conversation
                        .filter(Conversation.column(of: .conversationId) == conversationId)
                        .updateAll(db, [Conversation.column(of: .unseenMessageCount).set(to: 0)])
                }
                
                try ConversationDAO.shared.deleteFTSContent(with: conversationId, from: db)
                try PinMessageDAO.shared.deleteAll(conversationId: conversationId, from: db)
                db.afterNextTransactionCommit { (_) in
                    DispatchQueue.main.async {
                        switch intent {
                        case .delete:
                            NotificationCenter.default.post(name: conversationDidChangeNotification, object: nil)
                            hud.set(style: .notification, text: R.string.localizable.deleted())
                        case .clear:
                            let change = ConversationChange(conversationId: conversationId, action: .reload)
                            NotificationCenter.default.post(name: conversationDidChangeNotification, object: change)
                            hud.set(style: .notification, text: R.string.localizable.cleared())
                        }
                        hud.scheduleAutoHidden()
                        completion?()
                    }
                }
            }
        }
    }
    
}
