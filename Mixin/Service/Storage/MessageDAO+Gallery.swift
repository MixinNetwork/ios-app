import Foundation
import WCDBSwift
import MixinServices

extension MessageDAO {

    fileprivate static let sqlQueryGalleryItem = """
    SELECT conversation_id, id, category, media_url, media_mime_type, media_width,
           media_height, media_status, media_duration, thumb_image, thumb_url, created_at
    FROM messages
    WHERE %@ conversation_id = ? AND category in ('SIGNAL_IMAGE','PLAIN_IMAGE', 'SIGNAL_VIDEO', 'PLAIN_VIDEO', 'SIGNAL_LIVE', 'PLAIN_LIVE') AND status != 'FAILED' AND (NOT (user_id = ? AND media_status != 'DONE'))
    """
    
    func getGalleryItems(conversationId: String, location: GalleryItem?, count: Int) -> [GalleryItem] {
        assert(count != 0)
        var items = [GalleryItem]()
        let sql: String
        if let location = location {
            let rowId = MixinDatabase.shared.getRowId(tableName: Message.tableName,
                                                      condition: Message.Properties.messageId == location.messageId)
            if count > 0 {
                sql = String(format: Self.sqlQueryGalleryItem, "ROWID > \(rowId) AND ") + " ORDER BY created_at ASC LIMIT \(count)"
            } else {
                sql = String(format: Self.sqlQueryGalleryItem, "ROWID < \(rowId) AND ") + " ORDER BY created_at DESC LIMIT \(-count)"
            }
        } else {
            assert(count > 0)
            sql = String(format: Self.sqlQueryGalleryItem, "") + " ORDER BY created_at DESC LIMIT \(count)"
        }
        
        do {
            let stmt = StatementSelectSQL(sql: sql)
            let cs = try MixinDatabase.shared.database.prepare(stmt)
            
            let bindingCounter = Counter(value: 0)
            cs.bind(conversationId, toIndex: bindingCounter.advancedValue)
            cs.bind(myUserId, toIndex: bindingCounter.advancedValue)
            
            while try cs.step() {
                let counter = Counter(value: -1)
                let item = GalleryItem(conversationId: cs.value(atIndex: counter.advancedValue) ?? "",
                                       messageId: cs.value(atIndex: counter.advancedValue) ?? "",
                                       category: cs.value(atIndex: counter.advancedValue) ?? "",
                                       mediaUrl: cs.value(atIndex: counter.advancedValue),
                                       mediaMimeType: cs.value(atIndex: counter.advancedValue),
                                       mediaWidth: cs.value(atIndex: counter.advancedValue),
                                       mediaHeight: cs.value(atIndex: counter.advancedValue),
                                       mediaStatus: cs.value(atIndex: counter.advancedValue),
                                       mediaDuration: cs.value(atIndex: counter.advancedValue),
                                       thumbImage: cs.value(atIndex: counter.advancedValue),
                                       thumbUrl: cs.value(atIndex: counter.advancedValue),
                                       createdAt: cs.value(atIndex: counter.advancedValue) ?? "")
                if let item = item {
                    items.append(item)
                }
            }
        } catch {
            Logger.writeDatabase(error: error)
            reporter.report(error: error)
        }
        
        if count > 0 {
            return items
        } else {
            return items.reversed()
        }
    }
    
}
