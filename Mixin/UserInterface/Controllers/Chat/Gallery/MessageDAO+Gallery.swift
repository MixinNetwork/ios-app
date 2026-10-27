import Foundation
import GRDB
import MixinServices

extension MessageDAO {

    fileprivate static let sqlQueryGalleryItem = """
    SELECT conversation_id, id, category, media_url, media_mime_type, media_width,
           media_height, media_status, media_duration, thumb_image, thumb_url, created_at
    FROM messages
    WHERE %@ conversation_id = ?
        AND category in ('SIGNAL_IMAGE','PLAIN_IMAGE', 'ENCRYPTED_IMAGE', 'SIGNAL_VIDEO', 'PLAIN_VIDEO', 'ENCRYPTED_VIDEO', 'SIGNAL_LIVE', 'PLAIN_LIVE', 'ENCRYPTED_LIVE')
        AND status != 'FAILED'
        AND (NOT (user_id = ? AND media_status != 'DONE'))
    """
    
    func getGalleryItems(conversationId: String, location: GalleryItem?, count: Int) -> [GalleryItem] {
        assert(count != 0)
        var items = [GalleryItem]()
        let sql: String
        if location != nil {
            if count < 0 {
                sql = String(format: Self.sqlQueryGalleryItem, "") + " AND created_at <= ? AND id != ? ORDER BY created_at DESC, ROWID DESC LIMIT \(-count)"
            } else {
                sql = String(format: Self.sqlQueryGalleryItem, "") + " AND created_at >= ? AND id != ? ORDER BY created_at ASC, ROWID ASC LIMIT \(count)"
            }
        } else {
            assert(count > 0)
            sql = String(format: Self.sqlQueryGalleryItem, "") + " ORDER BY created_at DESC LIMIT \(count)"
        }
        do {
            try db.read { (db) -> Void in
                let rows: RowCursor
                if let location {
                    rows = try Row.fetchCursor(db, sql: sql, arguments: [conversationId, myUserId, location.createdAt, location.messageId], adapter: nil)
                } else {
                    rows = try Row.fetchCursor(db, sql: sql, arguments: [conversationId, myUserId], adapter: nil)
                }
                while let row = try rows.next() {
                    let counter = Counter(value: -1)
                    let item = GalleryItem(transcriptId: nil,
                                           conversationId: row[counter.advancedValue] ?? "",
                                           messageId: row[counter.advancedValue] ?? "",
                                           category: row[counter.advancedValue] ?? "",
                                           mediaUrl: row[counter.advancedValue],
                                           mediaMimeType: row[counter.advancedValue],
                                           mediaWidth: row[counter.advancedValue],
                                           mediaHeight: row[counter.advancedValue],
                                           mediaStatus: row[counter.advancedValue],
                                           mediaDuration: row[counter.advancedValue],
                                           thumbImage: row[counter.advancedValue],
                                           thumbUrl: row[counter.advancedValue],
                                           createdAt: row[counter.advancedValue] ?? "")
                    if let item = item {
                        items.append(item)
                    }
                }
            }
        } catch {
            Logger.database.error(category: "MessageDAO+Gallery", message: "\(error)")
            reporter.report(error: error)
        }
        
        if count > 0 {
            return items
        } else {
            return items.reversed()
        }
    }
    
}
