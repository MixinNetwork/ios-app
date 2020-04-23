import WCDBSwift

public class MixinDatabase: BaseDatabase {
    
    public static let shared = MixinDatabase()
    
    private static let version: Int = 21
    
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
                
                try database.create(of: Circle.self)
                try database.create(of: CircleConversation.self)
                
                try self.createAfter(database: database, localVersion: localVersion)
                
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerLastMessageInsert).execute()
                try database.prepareUpdateSQL(sql: MessageDAO.sqlTriggerLastMessageDelete).execute()
                
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
        
        if localVersion < 8 {
            try database.drop(table: "sent_sender_keys")
            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS jobs_next_indexs").execute()
        }
        
        if localVersion < 9 {
            try database.drop(table: "resend_messages")
        }

        if localVersion < 15 {
            try database.prepareUpdateSQL(sql: "DROP TRIGGER IF EXISTS conversation_unseen_message_count_insert").execute()
        }

        if localVersion < 18 {
            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS jobs_next_indexs").execute()
        }
    }
    
    private func createAfter(database: Database, localVersion: Int) throws {
        guard localVersion > 0 else {
            return
        }

        if localVersion < 11 {
            try database.prepareUpdateSQL(sql: "DELETE FROM participant_session WHERE ifnull(session_id,'') == ''").execute()
        }

        if localVersion < 18 {
            if try database.isColumnExist(tableName: Job.tableName, columnName: "is_http_message") {
                try database.prepareUpdateSQL(sql: "UPDATE jobs SET category = '\(JobCategory.WebSocket.rawValue)' WHERE is_http_message = 0").execute()
                try database.prepareUpdateSQL(sql: "UPDATE jobs SET category = '\(JobCategory.Http.rawValue)' WHERE is_http_message = 1").execute()
            }

            let jobs = try database.prepareSelectSQL(sql: "SELECT id FROM messages WHERE user_id = ? AND status = 'SENDING' AND media_status = 'PENDING' AND category in ('SIGNAL_IMAGE','SIGNAL_VIDEO','SIGNAL_DATA', 'SIGNAL_AUDIO','PLAIN_IMAGE','PLAIN_VIDEO','PLAIN_DATA', 'PLAIN_AUDIO')", values: [myUserId]).getStringValues().map { Job(attachmentMessage: $0, action: .UPLOAD_ATTACHMENT) }

            try database.insert(objects: jobs, intoTable: Job.tableName)

            try database.prepareUpdateSQL(sql: "DROP INDEX IF EXISTS messages_pending_indexs").execute()
        }

        if localVersion < 21 {
            try database.prepareUpdateSQL(sql: "UPDATE assets SET reserve = '0'").execute()
            try database.prepareUpdateSQL(sql: "UPDATE top_assets SET reserve = '0'").execute()
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
