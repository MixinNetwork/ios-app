import Foundation
import WCDBSwift
import MixinServices

extension MessageDAO {
    
    static let sqlQueryGalleryItem = """
    SELECT m.conversation_id, m.id, m.category, m.media_url, m.media_mime_type, m.media_width,
           m.media_height, m.media_status, m.media_duration, m.thumb_image, m.thumb_url, m.created_at
    FROM messages m
    WHERE conversation_id = ?
        AND (category in ('SIGNAL_IMAGE', 'SIGNAL_VIDEO', 'SIGNAL_LIVE', 'PLAIN_IMAGE', 'PLAIN_LIVE', 'PLAIN_VODE')) AND status != 'FAILED' AND (NOT (user_id = ? AND media_status != 'DONE'))
    """
    
    func getGalleryItems(conversationId: String, location: GalleryItem?, count: Int) -> [GalleryItem] {
        assert(count != 0)
        var items = [GalleryItem]()
        var sql = MessageDAO.sqlQueryGalleryItem
        if let location = location {
            if count > 0 {
                sql += " AND created_at >= '\(location.createdAt)' ORDER BY created_at ASC LIMIT \(count+1)"
            } else {
                sql += " AND created_at <= '\(location.createdAt)' ORDER BY created_at DESC LIMIT \(-count+1)"
            }
        } else {
            assert(count > 0)
            sql += " ORDER BY created_at DESC LIMIT \(count)"
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
                if let item = item , item.messageId != location?.messageId{
                    items.append(item)
                }
            }
        } catch {
            reporter.report(error: error)
        }
        
        if count > 0 {
            return items
        } else {
            return items.reversed()
        }
    }
    
}
