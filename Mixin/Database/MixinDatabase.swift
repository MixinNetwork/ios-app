import WCDBSwift
import Bugsnag

class MixinDatabase: BaseDatabase {

    private static let databaseVersion: Int = 3

    static let shared = MixinDatabase()

    private lazy var _database = Database(withPath: MixinFile.databasePath)
    override var database: Database! {
        get { return _database }
        set { }
    }

    private func upgrade(database: Database) throws {
        guard DatabaseUserDefault.shared.mixinDatabaseVersion < 3 && DatabaseUserDefault.shared.mixinDatabaseVersion > 0 else {
            return
        }

        if try database.isColumnExist(tableName: Message.tableName, columnName: "media_mine_type") {
            try database.prepareUpdateSQL(sql: "UPDATE messages SET media_mime_type = media_mine_type WHERE ifnull(media_mine_type, '') <> ''").execute()
        }
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
