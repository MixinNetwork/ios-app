import WCDBSwift

public class MixinDatabase: BaseDatabase {
    
    public static let shared = MixinDatabase()
    
    private static let version: Int = 13
    
    override public var database: Database! {
        get { _database }
        set { }
    }
    
    private var _database = Database(path: AppGroupContainer.mixinDatabaseUrl.path)
    
    public func initDatabase(clearSentSenderKey: Bool = false) {
        _database = Database(path: AppGroupContainer.mixinDatabaseUrl.path)
        do {
            try database.run(transaction: {
                var localVersion = try database.getDatabaseVersion()
                if localVersion == 0 {
                    // UserDefaults migration is performed before database opening
                    // Database won't be opened if UserDefaults migration fails (e.g. launched in App Extension)
                    // As long as database is open this is guaranteed running in main App
                    localVersion = DatabaseUserDefault.shared.mixinDatabaseVersion
                }
                try self.createBefore(database: database, localVersion: localVersion)
                
                try database.create(of: Asset.self)
                try database.create(table: Asset.topAssetsTableName, of: Asset.self)
                try database.create(of: Snapshot.self)
                try database.create(of: Sticker.self)
                try database.create(of: StickerRelationship.self)
                try database.create(of: Album.self)
                try database.create(of: MessageHistory.self)
                try database.create(of: App.self)
                
                try database.create(of: User.self)
                try database.create(of: Conversation.self)
                try database.create(of: Message.self)
                try database.create(of: Participant.self)
                
                try database.create(of: Address.self)
                try database.create(of: Job.self)
                try database.create(of: ResendSessionMessage.self)
                
                try database.create(of: FavoriteApp.self)
                try database.create(of: ParticipantSession.self)
                
                try database.create(of: MessageMention.self)
                
                try self.createAfter(database: database, localVersion: localVersion)
                
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerLastMessageInsert).execute()
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerLastMessageDelete).execute()
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerUnseenMessageInsert).execute()
                
                if clearSentSenderKey {
                    try database.update(maps: [(ParticipantSession.Properties.sentToServer, nil)], tableName: ParticipantSession.tableName)
                }
                try database.setDatabaseVersion(version: MixinDatabase.version)
            })
        } catch {
            reporter.report(error: error)
        }
    }
    
    private func createBefore(database: Database, localVersion: Int) throws {
        guard localVersion > 0 else {
            return
        }
        
        if localVersion < 4 {
            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS messages_index1").execute()
            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS messages_index2").execute()
        }
        
        if localVersion < 5 {
            try database.drop(table: Sticker.tableName)
            try database.drop(table: "sticker_albums")
        }
        
        if localVersion < 6 {
            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS messages_status_index").execute()
            try database.prepareUpdateSQL(sql: "DROP TRIGGER IF EXISTS conversation_unseen_message_count_update").execute()
        }
        
        if localVersion < 7 {
            try database.drop(table: Address.tableName)
            try database.drop(table: Asset.tableName)
            try database.drop(table: Asset.topAssetsTableName)
        }
        
        if localVersion < 8 {
            try database.drop(table: "sent_sender_keys")
            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS jobs_next_indexs").execute()
        }
        
        if localVersion < 9 {
            try database.drop(table: "resend_messages")
        }
    }
    
    private func createAfter(database: Database, localVersion: Int) throws {
        guard localVersion > 0 else {
            return
        }
        
        if localVersion < 4, try database.isColumnExist(tableName: Snapshot.tableName, columnName: "counter_user_id") {
            try database.prepareUpdateSQL(sql: "UPDATE snapshots SET opponent_id = counter_user_id").execute()
        }
        
        if localVersion < 8 {
            try database.update(maps: [(Job.Properties.isHttpMessage, true)], tableName: Job.tableName, condition: Job.Properties.action == JobAction.SEND_ACK_MESSAGE.rawValue || Job.Properties.action == JobAction.SEND_ACK_MESSAGES.rawValue || Job.Properties.action == JobAction.SEND_DELIVERED_ACK_MESSAGE.rawValue)
        }

        if localVersion < 11 {
            try database.prepareUpdateSQL(sql: "DELETE FROM participant_session WHERE ifnull(session_id,'') == ''").execute()
        }
    }
    
}

extension MixinDatabase {
    
    public class NullValue: ColumnEncodable {
        
        public static var columnType: ColumnType {
            return .null
        }
        
        public func archivedValue() -> FundamentalValue {
            return FundamentalValue(nil)
        }
        
    }
    
}
