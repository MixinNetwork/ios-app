import GRDB

public final class UserDatabase: Database {
    
    public private(set) static var current: UserDatabase! = try! UserDatabase(url: AppGroupContainer.mixinDatabaseUrl)
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "User"
        config.prepareDatabase { (db) in
            db.add(tokenizer: MixinTokenizer.self)
        }
        return config
    }
    
    public override var needsMigration: Bool {
        try! pool.read({ (db) -> Bool in
            let migrationsCompleted = try migrator.hasCompletedMigrations(db)
            return !migrationsCompleted
        })
    }
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v8") { db in
            try db.execute(sql: "DROP TABLE IF EXISTS sent_sender_keys")
            try db.execute(sql: "DROP INDEX IF EXISTS jobs_next_indexs")
        }
        
        migrator.registerMigration("v9") { db in
            try db.execute(sql: "DROP TABLE IF EXISTS resend_messages")
        }
        
        migrator.registerMigration("v15") { db in
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversation_unseen_message_count_insert")
        }
        
        migrator.registerMigration("v18") { db in
            try db.execute(sql: "DROP INDEX IF EXISTS jobs_next_indexs")
        }
        
        migrator.registerMigration("create_table") { db in
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS addresses(type TEXT, address_id TEXT PRIMARY KEY, asset_id TEXT, destination TEXT, label TEXT, tag TEXT, fee TEXT, reserve TEXT, dust TEXT, updated_at TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS albums(album_id TEXT PRIMARY KEY, name TEXT, icon_url TEXT, created_at TEXT, update_at TEXT, user_id TEXT, category TEXT, description TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS apps(app_id TEXT PRIMARY KEY, app_number TEXT, redirect_uri TEXT, name TEXT, category TEXT, icon_url TEXT, capabilites BLOB, resource_patterns BLOB, home_uri TEXT, creator_id TEXT, updated_at TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS assets(asset_id TEXT PRIMARY KEY, type TEXT, symbol TEXT, name TEXT, icon_url TEXT, balance TEXT, destination TEXT, tag TEXT, price_btc TEXT, price_usd TEXT, change_usd TEXT, chain_id TEXT, confirmations INTEGER, asset_key TEXT, reserve TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS circle_conversations(circle_id TEXT, conversation_id TEXT, user_id TEXT, created_at TEXT, pin_time TEXT, CONSTRAINT _multi_primary PRIMARY KEY(conversation_id, circle_id))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS circles(circle_id TEXT PRIMARY KEY, name TEXT, created_at TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS conversations(conversation_id TEXT PRIMARY KEY, owner_id TEXT, category TEXT, name TEXT, icon_url TEXT, announcement TEXT, last_message_id TEXT, last_message_created_at TEXT, last_read_message_id TEXT, unseen_message_count INTEGER, status INTEGER, draft TEXT, mute_until TEXT, code_url TEXT, pin_time TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS favorite_apps(user_id TEXT, app_id TEXT, created_at TEXT, CONSTRAINT _multi_primary PRIMARY KEY(user_id, app_id))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS jobs(orderId INTEGER PRIMARY KEY AUTOINCREMENT, job_id TEXT, priority INTEGER, blaze_message BLOB, blaze_message_data BLOB, action TEXT, category TEXT, conversation_id TEXT, user_id TEXT, resend_message_id TEXT, message_id TEXT, status TEXT, session_id TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS message_mentions(message_id TEXT PRIMARY KEY, conversation_id TEXT, mentions BLOB, has_read INTEGER)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS messages(id TEXT PRIMARY KEY, conversation_id TEXT, user_id TEXT, category TEXT, content TEXT, media_url TEXT, media_mime_type TEXT, media_size INTEGER, media_duration INTEGER, media_width INTEGER, media_height INTEGER, media_hash TEXT, media_key BLOB, media_digest BLOB, media_status TEXT, media_waveform BLOB, media_local_id TEXT, thumb_image TEXT, thumb_url TEXT, status TEXT, action TEXT, participant_id TEXT, snapshot_id TEXT, name TEXT, sticker_id TEXT, shared_user_id TEXT, quote_message_id TEXT, quote_content BLOB, created_at TEXT, CONSTRAINT _foreign_key_constraint FOREIGN KEY(conversation_id) REFERENCES conversations(conversation_id) ON DELETE CASCADE)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS messages_history(message_id TEXT PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS participant_session(conversation_id TEXT, user_id TEXT, session_id TEXT, sent_to_server INTEGER, created_at TEXT, CONSTRAINT _multi_primary PRIMARY KEY(conversation_id, user_id, session_id))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS participants(conversation_id TEXT, user_id TEXT, role TEXT, status INTEGER, created_at TEXT, CONSTRAINT _multi_primary PRIMARY KEY(conversation_id, user_id))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS resend_session_messages(message_id TEXT, user_id TEXT, session_id TEXT, status INTEGER, CONSTRAINT _multi_primary PRIMARY KEY(message_id, user_id, session_id))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS snapshots(snapshot_id TEXT PRIMARY KEY, type TEXT, asset_id TEXT, amount TEXT, opponent_id TEXT, transaction_hash TEXT, sender TEXT, receiver TEXT, memo TEXT, confirmations INTEGER, trace_id TEXT, created_at TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS sticker_relationships(album_id TEXT, sticker_id TEXT, created_at TEXT, CONSTRAINT _multi_primary PRIMARY KEY(album_id, sticker_id))")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS stickers(sticker_id TEXT PRIMARY KEY, name TEXT, asset_url TEXT, asset_type TEXT, asset_width INTEGER, asset_height INTEGER, last_used_at TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS top_assets(asset_id TEXT PRIMARY KEY, type TEXT, symbol TEXT, name TEXT, icon_url TEXT, balance TEXT, destination TEXT, tag TEXT, price_btc TEXT, price_usd TEXT, change_usd TEXT, chain_id TEXT, confirmations INTEGER, asset_key TEXT, reserve TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS traces(trace_id TEXT PRIMARY KEY, asset_id TEXT, amount TEXT, opponent_id TEXT, destination TEXT, tag TEXT, snapshot_id TEXT, created_at TEXT)")
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS users(user_id TEXT PRIMARY KEY, full_name TEXT, biography TEXT, identity_number TEXT, avatar_url TEXT, phone TEXT, is_verified INTEGER, mute_until TEXT, app_id TEXT, relationship TEXT, created_at TEXT, is_scam INTEGER)")
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS conversations_indexs ON conversations(pin_time, last_message_created_at)")
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS jobs_index_id ON jobs(job_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS jobs_next_indexs ON jobs(category, priority DESC, orderId ASC)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS message_mentions_conversation_indexs ON message_mentions(conversation_id, has_read)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_category_indexs ON messages(category, status)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_page_indexs ON messages(conversation_id, created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_pending_indexs ON messages(user_id, status, created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_unread_indexs ON messages(conversation_id, status, created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_user_indexs ON messages(conversation_id, user_id, created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS users_app_indexs ON users(app_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS users_identity_number_indexs ON users(identity_number)")
            
            let lastMessageDelete = """
            CREATE TRIGGER IF NOT EXISTS conversation_last_message_delete AFTER DELETE ON messages
            BEGIN
                UPDATE conversations SET last_message_id = (select id from messages where conversation_id = old.conversation_id order by created_at DESC limit 1) WHERE conversation_id = old.conversation_id;
            END
            """
            let lastMessageUpdate = """
            CREATE TRIGGER IF NOT EXISTS conversation_last_message_update AFTER INSERT ON messages
            BEGIN
                UPDATE conversations SET last_message_id = new.id, last_message_created_at = new.created_at WHERE conversation_id = new.conversation_id;
            END
            """
            try db.execute(sql: lastMessageDelete)
            try db.execute(sql: lastMessageUpdate)
        }
        
        migrator.registerMigration("v11") { (db) in
            try db.execute(sql: "DELETE FROM participant_session WHERE ifnull(session_id,'') == ''")
        }
        
        migrator.registerMigration("v18_2") { (db) in
            let infos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(jobs)")
            let columnNames = Set(infos.map(\.name))
            if columnNames.contains("is_http_message") {
                try db.execute(sql: "UPDATE jobs SET category = '\(JobCategory.WebSocket.rawValue)' WHERE is_http_message = 0")
                try db.execute(sql: "UPDATE jobs SET category = '\(JobCategory.Http.rawValue)' WHERE is_http_message = 1")
            }
            
            let pendingUploadMessageIDSQL = """
            SELECT id
            FROM messages
            WHERE user_id = ?
                AND status = 'SENDING'
                AND media_status = 'PENDING'
                AND category in ('SIGNAL_IMAGE','SIGNAL_VIDEO','SIGNAL_DATA', 'SIGNAL_AUDIO','PLAIN_IMAGE','PLAIN_VIDEO','PLAIN_DATA', 'PLAIN_AUDIO')
            """
            let pendingUploadMessageIDs = try String.fetchAll(db, sql: pendingUploadMessageIDSQL, arguments: [myUserId], adapter: nil)
            for id in pendingUploadMessageIDs {
                let job = Job(attachmentMessage: id, action: .UPLOAD_ATTACHMENT)
                try job.save(db)
            }
            
            try db.execute(sql: "DROP INDEX IF EXISTS messages_pending_indexs")
        }
        
        migrator.registerMigration("v21") { (db) in
            try db.execute(sql: "UPDATE assets SET reserve = '0'")
            try db.execute(sql: "UPDATE top_assets SET reserve = '0'")
        }
        
        migrator.registerMigration("fts5") { (db) in
            try db.create(virtualTable: Message.ftsTableName, using: FTS5()) { t in
                t.tokenizer = MixinTokenizer.tokenizerDescriptor()
                t.column(Message.column(of: .messageId).name).notIndexed()
                t.column(Message.column(of: .conversationId).name).notIndexed()
                t.column(Message.column(of: .content).name)
                t.column(Message.column(of: .name).name)
            }
        }
        
        return migrator
    }
    
    public static func rebuildCurrent() {
        current = try! UserDatabase(url: AppGroupContainer.mixinDatabaseUrl)
        current.migrate()
    }
    
    public func clearSentSenderKey() {
        try! pool.barrierWriteWithoutTransaction { (db) -> Void in
            try ParticipantSession.updateAll(db, [ParticipantSession.column(of: .sentToServer).set(to: nil)])
        }
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
