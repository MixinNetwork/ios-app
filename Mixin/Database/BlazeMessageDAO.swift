import WCDBSwift

final class BlazeMessageDAO {

    static let shared = BlazeMessageDAO()

    private let jsonDecoder = JSONDecoder()

    func isExist(data: BlazeMessageData) -> Bool {
        return MixinDatabase.shared.isExist(type: MessageBlaze.self, condition: MessageBlaze.Properties.messageId == data.messageId)
    }

    func insertOrReplace(messageId: String, data: String?, createdAt: String) -> Bool {
        guard let data = data?.data(using: .utf8) else {
            return false
        }
        return MixinDatabase.shared.insertOrReplace(objects: [MessageBlaze(messageId: messageId, message: data, createdAt: createdAt)])
    }

    func getCount() -> Int {
        return MixinDatabase.shared.getCount(on: MessageBlaze.Properties.messageId.count(), fromTable: MessageBlaze.tableName)
    }

    func getBlazeMessageData(limit: Int) -> [BlazeMessageData] {
        return MixinDatabase.shared.getCodables(on: [MessageBlaze.Properties.message], fromTable: MessageBlaze.tableName, orderBy: [MessageBlaze.Properties.createdAt.asOrder(by: .ascending)], limit: limit) { (rows) -> [BlazeMessageData] in
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
        MixinDatabase.shared.delete(table: MessageBlaze.tableName, condition: MessageBlaze.Properties.messageId == data.messageId)
    }
}

