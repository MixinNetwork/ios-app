import WCDBSwift

public final class BlazeMessageDAO {
    
    static let shared = BlazeMessageDAO()
    
    private let jsonDecoder = JSONDecoder()
    
    func isExist(data: BlazeMessageData) -> Bool {
        return TaskDatabase.shared.isExist(type: MessageBlaze.self, condition: MessageBlaze.Properties.messageId == data.messageId)
    }
    
    func insertOrReplace(messageId: String, conversationId: String, data: Data, createdAt: String) -> Bool {
        return TaskDatabase.shared.insertOrReplace(objects: [MessageBlaze(messageId: messageId, conversationId: conversationId, message: data, createdAt: createdAt)])
    }
    
    func getCount() -> Int {
        return TaskDatabase.shared.getCount(on: MessageBlaze.Properties.messageId.count(), fromTable: MessageBlaze.tableName)
    }
    
    func getBlazeMessageData(limit: Int) -> [BlazeMessageData] {
        return TaskDatabase.shared.getCodables(on: [MessageBlaze.Properties.message], fromTable: MessageBlaze.tableName, orderBy: [MessageBlaze.Properties.createdAt.asOrder(by: .ascending)], limit: limit) { (rows) -> [BlazeMessageData] in
            var result = [BlazeMessageData]()
            for row in rows {
                guard let data = (try? jsonDecoder.decode(BlazeMessageData.self, from: row[0].dataValue)) else {
                    continue
                }
                result.append(data)
            }
            return result
        }
    }
    
    func delete(data: BlazeMessageData) {
        TaskDatabase.shared.delete(table: MessageBlaze.tableName, condition: MessageBlaze.Properties.messageId == data.messageId)
    }
    
}
