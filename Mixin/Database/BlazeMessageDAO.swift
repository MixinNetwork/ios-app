import WCDBSwift

final class BlazeMessageDAO {

    static let shared = BlazeMessageDAO()

    private let jsonDecoder = JSONDecoder()

    func isExist(data: BlazeMessageData) -> Bool {
        return JobDatabase.getIntance().isExist(type: MessageBlaze.self, condition: MessageBlaze.Properties.messageId == data.messageId)
    }

    func insertOrReplace(messageId: String, data: String?, createdAt: String) -> Bool {
        guard let data = data?.data(using: .utf8) else {
            return false
        }
        return JobDatabase.getIntance().insertOrReplace(objects: [MessageBlaze(messageId: messageId, message: data, createdAt: createdAt)])
    }

    func getCount() -> Int {
        return JobDatabase.getIntance().getCount(on: MessageBlaze.Properties.messageId.count(), fromTable: MessageBlaze.tableName)
    }

    func getBlazeMessageData(limit: Int) -> [BlazeMessageData] {
        return JobDatabase.getIntance().getCodables(on: [MessageBlaze.Properties.message], fromTable: MessageBlaze.tableName, orderBy: [MessageBlaze.Properties.createdAt.asOrder(by: .ascending)], limit: limit) { (rows) -> [BlazeMessageData] in
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
        JobDatabase.getIntance().delete(table: MessageBlaze.tableName, condition: MessageBlaze.Properties.messageId == data.messageId)
    }
}

