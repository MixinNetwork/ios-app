import WCDBSwift
import Bugsnag

class MixinDatabase: BaseDatabase {

    private static let databaseVersion: Int = 6

    static let shared = MixinDatabase()

    private lazy var _database = Database(withPath: MixinFile.databasePath)
    override var database: Database! {
        get { return _database }
        set { }
    }

    private func upgrade(database: Database) throws {
        guard DatabaseUserDefault.shared.mixinDatabaseVersion < 6 && DatabaseUserDefault.shared.mixinDatabaseVersion > 0 else {
            return
        }

        try database.drop(table: Sticker.tableName)
        try database.drop(table: "sticker_album")
    }

    override func configure(reset: Bool = false) {
        if MixinFile.databasePath != _database.path {
            _database.close()
            _database = Database(withPath: MixinFile.databasePath)
        }
        do {
            try database.run(transaction: {
                try self.upgrade(database: database)

                try database.create(of: Asset.self)
                try database.create(of: Snapshot.self)
                try database.create(of: Sticker.self)
                try database.create(of: StickerRelationship.self)
                try database.create(of: Album.self)
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
