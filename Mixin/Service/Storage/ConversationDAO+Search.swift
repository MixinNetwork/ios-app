import Foundation
import GRDB
import MixinServices

extension ConversationDAO {
    
    func getConversation(from snapshot: DatabaseSnapshot, with keyword: String, limit: Int?) -> [MessagesWithinConversationSearchResult] {
        if AppGroupUserDefaults.Database.isFTSInitialized {
            return getConversationWithFTS(from: snapshot, with: keyword, limit: limit)
        } else {
            return getConversationWithoutFTS(from: snapshot, with: keyword, limit: limit)
        }
    }
    
    private func getConversationWithFTS(from snapshot: DatabaseSnapshot, with keyword: String, limit: Int?) -> [MessagesWithinConversationSearchResult] {
        let cids = snapshot.read { (db) -> [String] in
            do {
                var sql = "SELECT DISTINCT conversation_id FROM \(Message.ftsTableName) WHERE content MATCH ? ORDER BY rowid DESC"
                if let limit = limit {
                    sql += " LIMIT \(limit)"
                }
                return try String.fetchAll(db, sql: sql, arguments: ["\"\(keyword)\""], adapter: nil)
            } catch {
                Logger.writeDatabase(error: error)
                return []
            }
        }
        guard !cids.isEmpty else {
            return []
        }
        let sql = """
            SELECT cid, c.category,
                CASE c.category WHEN 'CONTACT' THEN u.full_name ELSE c.name END,
                CASE c.category WHEN 'CONTACT' THEN u.avatar_url ELSE c.icon_url END,
                CASE c.category WHEN 'CONTACT' THEN u.user_id ELSE NULL END,
                u.is_verified, u.app_id, count
            FROM (SELECT ttou(conversation_id) AS cid, COUNT(1) AS count FROM \(Message.ftsTableName) WHERE \(Message.ftsTableName) MATCH :keyword)
                LEFT JOIN conversations c ON cid = c.conversation_id
                LEFT JOIN users u ON c.owner_id = u.user_id
            ORDER BY c.last_message_created_at DESC
        """
        var results = [MessagesWithinConversationSearchResult]()
        snapshot.read { (db) -> Void in
            for cid in cids {
                if cid.isEmpty {
                    Logger.writeDatabase(log: "[FTS] Got empty cid")
                }
                let arguments = ["keyword": "(content : \"\(keyword)\") AND (conversation_id : \"\(uuidTokenString(uuidString: cid))\")"]
                let resultsInConversation = searchResults(db, with: sql, arguments: arguments, keyword: keyword)
                results.append(contentsOf: resultsInConversation)
            }
        }
        return results
    }
    
    private func getConversationWithoutFTS(from snapshot: DatabaseSnapshot, with keyword: String, limit: Int?) -> [MessagesWithinConversationSearchResult] {
        var sql = """
            SELECT m.conversation_id, c.category,
                CASE c.category WHEN 'CONTACT' THEN u.full_name ELSE c.name END,
                CASE c.category WHEN 'CONTACT' THEN u.avatar_url ELSE c.icon_url END,
                CASE c.category WHEN 'CONTACT' THEN u.user_id ELSE NULL END,
                u.is_verified, u.app_id, COUNT(m.conversation_id)
            FROM messages m
                LEFT JOIN conversations c ON m.conversation_id = c.conversation_id
                LEFT JOIN users u ON c.owner_id = u.user_id
            WHERE m.category in ('SIGNAL_TEXT','SIGNAL_DATA','SIGNAL_POST','PLAIN_TEXT','PLAIN_DATA','PLAIN_POST')
                AND m.status != 'FAILED'
                AND (m.content LIKE :keyword ESCAPE '/' OR m.name LIKE :keyword ESCAPE '/')
            GROUP BY m.conversation_id
            ORDER BY c.last_message_created_at DESC
        """
        if let limit = limit {
            sql += "\nLIMIT \(limit)"
        }
        let arguments = ["keyword": "%\(keyword.sqlEscaped)%"]
        return snapshot.read { (db) -> [MessagesWithinConversationSearchResult] in
            searchResults(db, with: sql, arguments: arguments, keyword: keyword)
        }
    }
    
    private func searchResults(_ db: GRDB.Database, with sql: String, arguments: [String: String], keyword: String) -> [MessagesWithinConversationSearchResult] {
        do {
            var items = [MessagesWithinConversationSearchResult]()
            let rows = try Row.fetchCursor(db, sql: sql, arguments: StatementArguments(arguments), adapter: nil)
            while let row = try rows.next() {
                let counter = Counter(value: -1)
                let conversationId: String = row[counter.advancedValue] ?? ""
                let categoryString: String = row[counter.advancedValue] ?? ""
                guard let category = ConversationCategory(rawValue: categoryString) else {
                    continue
                }
                let name: String = row[counter.advancedValue] ?? ""
                let iconUrl: String = row[counter.advancedValue] ?? ""
                let userId: String = row[counter.advancedValue] ?? ""
                let userIsVerified: Bool = row[counter.advancedValue] ?? false
                let userAppId: String? = row[counter.advancedValue]
                let relatedMessageCount: Int = row[counter.advancedValue] ?? 0
                let item: MessagesWithinConversationSearchResult
                switch category {
                case .CONTACT:
                    item = MessagesWithUserSearchResult(conversationId: conversationId,
                                                        name: name,
                                                        iconUrl: iconUrl,
                                                        userId: userId,
                                                        userIsVerified: userIsVerified,
                                                        userAppId: userAppId,
                                                        relatedMessageCount: relatedMessageCount,
                                                        keyword: keyword)
                case .GROUP:
                    item = MessagesWithGroupSearchResult(conversationId: conversationId,
                                                         name: name,
                                                         iconUrl: iconUrl,
                                                         relatedMessageCount: relatedMessageCount,
                                                         keyword: keyword)
                }
                items.append(item)
            }
            return items
        } catch DatabaseError.SQLITE_INTERRUPT {
            return []
        } catch {
            Logger.writeDatabase(error: error)
            return []
        }
    }
    
}
