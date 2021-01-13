import GRDB

public final class BlazeMessageDAO {
    
    public static let shared = BlazeMessageDAO()
    
    public func isExist(data: BlazeMessageData) -> Bool {
        TaskDatabase.current.recordExists(in: MessageBlaze.self, where: MessageBlaze.column(of: .messageId) == data.messageId)
    }
    
    public func save(messageId: String, conversationId: String, data: Data, createdAt: String) -> Bool {
        let msg = MessageBlaze(messageId: messageId, message: data, createdAt: createdAt)
        return TaskDatabase.current.save(msg)
    }
    
    public func getCount() -> Int {
        TaskDatabase.current.count(in: MessageBlaze.self)
    }
    
    func getMessageBlaze(messageId: String) -> MessageBlaze? {
        TaskDatabase.current.select(where: MessageBlaze.column(of: .messageId) == messageId)
    }
    
    public func getBlazeMessageData(createdAt: String? = nil, limit: Int) -> [BlazeMessageData] {
        let condition: SQLSpecificExpressible?
        if let createdAt = createdAt {
            condition = MessageBlaze.column(of: .createdAt) <= createdAt
        } else {
            condition = nil
        }
        let data: [Data] = TaskDatabase.current.select(column: MessageBlaze.column(of: .message),
                                                       from: MessageBlaze.self,
                                                       where: condition,
                                                       order: [MessageBlaze.column(of: .createdAt).asc],
                                                       limit: limit)
        return data.compactMap { (data) -> BlazeMessageData? in
            try? JSONDecoder.default.decode(BlazeMessageData.self, from: data)
        }
    }
    
    public func delete(data: BlazeMessageData) {
        TaskDatabase.current.delete(MessageBlaze.self,
                                    where: MessageBlaze.column(of: .messageId) == data.messageId)
    }
    
}
