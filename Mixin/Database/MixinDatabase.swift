import WCDBSwift
import Bugsnag

class MixinDatabase: BaseDatabase {

    private static let databaseVersion: Int = 2

    static let shared = MixinDatabase()

    private lazy var _database = Database(withPath: MixinFile.databasePath)
    override var database: Database! {
        get { return _database }
        set { }
    }

    private func upgrade(database: Database) throws {
        guard try database.isTableExists(MessageJob.tableName) else {
            return
        }

        let messageJobs: [MessageJob] = try database.getObjects(on: MessageJob.Properties.all, fromTable: MessageJob.tableName)
        var jobs = [Job]()
        if messageJobs.count > 0 {
            jobs = messageJobs.flatMap { Job(job: $0) }
            try database.insertOrReplace(objects: jobs, intoTable: Job.tableName)
        }
        try database.drop(table: MessageJob.tableName)

        let sendMessages: [Message] = try database.getObjects(on: Message.Properties.all, fromTable: Message.tableName, where: Message.Properties.status == MessageStatus.SENDING.rawValue, orderBy: [Message.Properties.createdAt.asOrder(by: .ascending)]).filter { $0.category.hasSuffix("_TEXT") || $0.category.hasSuffix("_STICKER") || $0.category.hasSuffix("_CONTACT") || $0.mediaStatus == MediaStatus.DONE.rawValue }
        if sendMessages.count > 0 {
            jobs = sendMessages.flatMap { Job(message: $0) }
            try database.insertOrReplace(objects: jobs, intoTable: Job.tableName)
        }

        let ackMessages: [MessageAck] = try database.getObjects(on: MessageAck.Properties.all, fromTable: MessageAck.tableName)
        if ackMessages.count > 0 {
            jobs = ackMessages.flatMap { Job(ack: $0) }
            try database.insertOrReplace(objects: jobs, intoTable: Job.tableName)
        }
        try database.drop(table: MessageAck.tableName)

        print("======MixinDatabase...upgrade...messageJobs:\(messageJobs.count)...sendMessages:\(jobs.count)...ackMessages:\(ackMessages.count)")
    }

    override func configure(reset: Bool = false) {
        if MixinFile.databasePath != _database.path {
            _database.close()
            _database = Database(withPath: MixinFile.databasePath)
        }
        do {
            try database.run(transaction: {
                try database.create(of: Asset.self)
                try database.create(of: Snapshot.self)
                try database.create(of: Sticker.self)
                try database.create(of: StickerAlbum.self)
                try database.create(of: MessageBlaze.self)
                try database.create(of: MessageHistory.self)
                try database.create(of: SentSenderKey.self)
                try database.create(of: App.self)

                try database.create(of: User.self)
                try database.create(of: Conversation.self)
                try database.create(of: Message.self)
                try database.create(of: Participant.self)
                
                try database.create(of: Address.self)
                try database.create(of: Job.self)
                try database.create(of: ResendMessage.self)

                try self.upgrade(database: database)

                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerLastMessageInsert).execute()
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerLastMessageDelete).execute()
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerUnseenMessageInsert).execute()
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerUnseenMessageUpdate).execute()

                DatabaseUserDefault.shared.mixinDatabaseVersion = MixinDatabase.databaseVersion
            })
            #if DEBUG
                print("======MixinDatabase...configure...success...")
            #endif
        } catch {
            Bugsnag.notifyError(error)
        }
    }

    func logout() {
        deleteAll(table: SentSenderKey.tableName)
        database.close()
    }
    
}

extension MixinDatabase {
    
    class NullValue: FundamentalColumnType, ColumnEncodableBase {
        
        static var columnType: ColumnType {
            return .null
        }
        
        var columnType: ColumnType {
            return .null
        }
        
        func archivedFundamentalValue() -> FundamentalColumnType? {
            return self
        }
        
    }

}
