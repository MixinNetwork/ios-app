import GRDB

public final class BlazeMessageDAO {
    
    public static let shared = BlazeMessageDAO()
    
    public func isExist(data: BlazeMessageData) -> Bool {
        TaskDatabase.current.recordExists(in: MessageBlaze.self, where: MessageBlaze.column(of: .messageId) == data.messageId)
    }
    
    public func save(messageId: String, conversationId: String, data: Data, createdAt: String) -> Bool {
        let msg = MessageBlaze(messageId: messageId, message: data, conversationId: conversationId, createdAt: createdAt)
        return TaskDatabase.current.save(msg)
    }
    
    public func getLastBlazeMessageCreatedAt() -> String? {
        return TaskDatabase.current.select(column: MessageBlaze.column(of: .createdAt),
                                           from: MessageBlaze.self,
                                           order: [MessageBlaze.column(of: .createdAt).desc],
                                           limit: 1).first
    }
    
    public func getCount() -> Int {
        TaskDatabase.current.count(in: MessageBlaze.self)
    }
    
    func getMessageBlaze(messageId: String) -> MessageBlaze? {
        TaskDatabase.current.select(where: MessageBlaze.column(of: .messageId) == messageId)
    }
    
    public func getBlazeMessages(createdAt: String? = nil, limit: Int) -> [MessageBlaze] {
        let condition: SQLSpecificExpressible?
        if let createdAt = createdAt {
            condition = MessageBlaze.column(of: .createdAt) <= createdAt
        } else {
            condition = nil
        }
        return TaskDatabase.current.select(where: condition,
                                           order: [MessageBlaze.column(of: .createdAt).asc],
                                           limit: limit)
    }
    
    public func getBlazeMessageData(conversationId: String, limit: Int) -> [BlazeMessageData] {
        let condition: SQLSpecificExpressible = MessageBlaze.column(of: .conversationId) == conversationId
        let data: [Data] = TaskDatabase.current.select(column: MessageBlaze.column(of: .message),
                                                       from: MessageBlaze.self,
                                                       where: condition,
                                                       order: [MessageBlaze.column(of: .createdAt).asc],
                                                       limit: limit)
        return data.compactMap { (data) -> BlazeMessageData? in
            try? JSONDecoder.default.decode(BlazeMessageData.self, from: data)
        }
    }
    
    public func delete(messageId: String) {
        TaskDatabase.current.delete(MessageBlaze.self,
                                    where: MessageBlaze.column(of: .messageId) == messageId)
    }
    
    public func delete(messageIds: [String]) {
        TaskDatabase.current.delete(MessageBlaze.self,
                                    where: messageIds.contains(MessageBlaze.column(of: .messageId)))
    }
    
    
}
