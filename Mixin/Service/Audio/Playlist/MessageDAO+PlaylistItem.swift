import Foundation
import GRDB
import MixinServices

extension MessageDAO {
    
    func getPlaylistItems(ofConversationWith conversationId: String, aboveMessageWith messageId: String) -> [PlaylistItem] {
        let sql = """
            SELECT id, conversation_id, media_url, name
            FROM messages
            WHERE conversation_id = ?
                AND category in ('SIGNAL_DATA', 'PLAIN_DATA')
                AND media_mime_type = 'audio/mpeg'
                AND rowid < ?
            ORDER BY created_at DESC
        """
        let rowId: Int? = db.select(column: .rowID,
                                    from: Message.self,
                                    where: Message.column(of: .messageId) == messageId)
        if let id = rowId {
            let messages: [PlaylistItem] = db.select(with: sql, arguments: [conversationId, id])
            return messages.reversed()
        } else {
            return []
        }
    }
    
    func getPlaylistItems(ofConversationWith conversationId: String, belowMessageWith messageId: String) -> [PlaylistItem] {
        let sql = """
            SELECT id, conversation_id, media_url, name
            FROM messages
            WHERE conversation_id = ?
                AND category in ('SIGNAL_DATA', 'PLAIN_DATA')
                AND media_mime_type = 'audio/mpeg'
                AND rowid > ?
            ORDER BY created_at ASC
        """
        let rowId: Int? = db.select(column: .rowID,
                                    from: Message.self,
                                    where: Message.column(of: .messageId) == messageId)
        if let id = rowId {
            return db.select(with: sql, arguments: [conversationId, id])
        } else {
            return []
        }
    }
    
}
