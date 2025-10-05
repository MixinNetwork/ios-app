import GRDB

public final class UserDatabase: Database {
    
    public private(set) static var current: UserDatabase! = makeDatabaseWithDefaultLocation()
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "User"
        config.foreignKeysEnabled = false
        config.prepareDatabase { (db) in
            db.add(tokenizer: MixinTokenizer.self)
            db.add(function: .uuidToToken)
            db.add(function: .tokenToUUID)
            db.add(function: .iso8601ToUnixTime)
            db.add(function: .ftsContent)
        }
        return config
    }
    
    public override var needsMigration: Bool {
        try! read { (db) -> Bool in
            let migrationsCompleted = try migrator.hasCompletedMigrations(db)
            return !migrationsCompleted
        }
    }
    
    internal lazy var tableMigrations: [ColumnMigratable] = [
        ColumnMigratableTableDefinition<Address>(constraints: nil, columns: [
            .init(key: .type, constraints: "TEXT NOT NULL"),
            .init(key: .addressId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .assetId, constraints: "TEXT NOT NULL"),
            .init(key: .destination, constraints: "TEXT NOT NULL"),
            .init(key: .label, constraints: "TEXT NOT NULL"),
            .init(key: .tag, constraints: "TEXT"),
            .init(key: .fee, constraints: "TEXT NOT NULL"),
            .init(key: .dust, constraints: "TEXT"),
            .init(key: .updatedAt, constraints: "TEXT NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<Album>(constraints: nil, columns: [
            .init(key: .albumId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .iconUrl, constraints: "TEXT NOT NULL"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
            .init(key: .updatedAt, constraints: "TEXT NOT NULL"),
            .init(key: .userId, constraints: "TEXT NOT NULL"),
            .init(key: .category, constraints: "TEXT NOT NULL"),
            .init(key: .description, constraints: "TEXT NOT NULL"),
            .init(key: .banner, constraints: "TEXT"),
            .init(key: .orderedAt, constraints: "INTEGER NOT NULL DEFAULT 0"),
            .init(key: .isAdded, constraints: "INTEGER NOT NULL DEFAULT 0"),
            .init(key: .isVerified, constraints: "INTEGER NOT NULL DEFAULT 0"),
        ]),
        ColumnMigratableTableDefinition<App>(constraints: nil, columns: [
            .init(key: .appId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .appNumber, constraints: "TEXT NOT NULL"),
            .init(key: .redirectUri, constraints: "TEXT NOT NULL"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .category, constraints: "TEXT"),
            .init(key: .iconUrl, constraints: "TEXT NOT NULL"),
            .init(key: .capabilities, constraints: "BLOB"),
            .init(key: .resourcePatterns, constraints: "BLOB"),
            .init(key: .homeUri, constraints: "TEXT NOT NULL"),
            .init(key: .creatorId, constraints: "TEXT NOT NULL"),
            .init(key: .updatedAt, constraints: "TEXT"),
        ]),
        ColumnMigratableTableDefinition<Asset>(constraints: nil, columns: [
            .init(key: .assetId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .type, constraints: "TEXT NOT NULL"),
            .init(key: .symbol, constraints: "TEXT NOT NULL"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .iconUrl, constraints: "TEXT NOT NULL"),
            .init(key: .balance, constraints: "TEXT NOT NULL"),
            .init(key: .destination, constraints: "TEXT"),
            .init(key: .tag, constraints: "TEXT"),
            .init(key: .priceBtc, constraints: "TEXT NOT NULL"),
            .init(key: .priceUsd, constraints: "TEXT NOT NULL"),
            .init(key: .changeUsd, constraints: "TEXT NOT NULL"),
            .init(key: .chainId, constraints: "TEXT NOT NULL"),
            .init(key: .confirmations, constraints: "INTEGER NOT NULL"),
            .init(key: .assetKey, constraints: "TEXT"),
            .init(key: .reserve, constraints: "TEXT"),
            .init(key: .depositEntries, constraints: "TEXT"),
        ]),
        ColumnMigratableTableDefinition<CircleConversation>(constraints: "PRIMARY KEY(conversation_id, circle_id)", columns: [
            .init(key: .circleId, constraints: "TEXT NOT NULL"),
            .init(key: .conversationId, constraints: "TEXT NOT NULL"),
            .init(key: .userId, constraints: "TEXT"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
            .init(key: .pinTime, constraints: "TEXT"),
        ]),
        ColumnMigratableTableDefinition<Circle>(constraints: nil, columns: [
            .init(key: .circleId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<Conversation>(constraints: nil, columns: [
            .init(key: .conversationId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .ownerId, constraints: "TEXT"),
            .init(key: .category, constraints: "TEXT"),
            .init(key: .name, constraints: "TEXT"),
            .init(key: .iconUrl, constraints: "TEXT"),
            .init(key: .announcement, constraints: "TEXT"),
            .init(key: .lastMessageId, constraints: "TEXT"),
            .init(key: .lastMessageCreatedAt, constraints: "TEXT"),
            .init(key: .lastReadMessageId, constraints: "TEXT"),
            .init(key: .unseenMessageCount, constraints: "INTEGER"),
            .init(key: .status, constraints: "INTEGER NOT NULL"),
            .init(key: .draft, constraints: "TEXT"),
            .init(key: .muteUntil, constraints: "TEXT"),
            .init(key: .codeUrl, constraints: "TEXT"),
            .init(key: .pinTime, constraints: "TEXT"),
            .init(key: .expireIn, constraints: "INTEGER"),
        ]),
        ColumnMigratableTableDefinition<FavoriteApp>(constraints: "PRIMARY KEY(user_id, app_id)", columns: [
            .init(key: .userId, constraints: "TEXT NOT NULL"),
            .init(key: .appId, constraints: "TEXT NOT NULL"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<Job>(constraints: nil, columns: [
            .init(key: .orderId, constraints: "INTEGER PRIMARY KEY AUTOINCREMENT"),
            .init(key: .jobId, constraints: "TEXT NOT NULL"),
            .init(key: .priority, constraints: "INTEGER NOT NULL"),
            .init(key: .blazeMessage, constraints: "BLOB"),
            .init(key: .blazeMessageData, constraints: "BLOB"),
            .init(key: .action, constraints: "TEXT NOT NULL"),
            .init(key: .category, constraints: "TEXT"),
            .init(key: .conversationId, constraints: "TEXT"),
            .init(key: .userId, constraints: "TEXT"),
            .init(key: .resendMessageId, constraints: "TEXT"),
            .init(key: .messageId, constraints: "TEXT"),
            .init(key: .status, constraints: "TEXT"),
            .init(key: .sessionId, constraints: "TEXT"),
        ]),
        ColumnMigratableTableDefinition<MessageMention>(constraints: nil, columns: [
            .init(key: .messageId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .conversationId, constraints: "TEXT NOT NULL"),
            .init(key: .mentionsJson, constraints: "BLOB NOT NULL"),
            .init(key: .hasRead, constraints: "INTEGER NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<Message>(constraints: nil, columns: [
            .init(key: .messageId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .conversationId, constraints: "TEXT NOT NULL"),
            .init(key: .userId, constraints: "TEXT NOT NULL"),
            .init(key: .category, constraints: "TEXT NOT NULL"),
            .init(key: .content, constraints: "TEXT"),
            .init(key: .mediaUrl, constraints: "TEXT"),
            .init(key: .mediaMimeType, constraints: "TEXT"),
            .init(key: .mediaSize, constraints: "INTEGER"),
            .init(key: .mediaDuration, constraints: "INTEGER"),
            .init(key: .mediaWidth, constraints: "INTEGER"),
            .init(key: .mediaHeight, constraints: "INTEGER"),
            .init(key: .mediaHash, constraints: "TEXT"),
            .init(key: .mediaKey, constraints: "BLOB"),
            .init(key: .mediaDigest, constraints: "BLOB"),
            .init(key: .mediaStatus, constraints: "TEXT"),
            .init(key: .mediaWaveform, constraints: "BLOB"),
            .init(key: .mediaLocalIdentifier, constraints: "TEXT"),
            .init(key: .thumbImage, constraints: "TEXT"),
            .init(key: .thumbUrl, constraints: "TEXT"),
            .init(key: .status, constraints: "TEXT NOT NULL"),
            .init(key: .action, constraints: "TEXT"),
            .init(key: .participantId, constraints: "TEXT"),
            .init(key: .snapshotId, constraints: "TEXT"),
            .init(key: .name, constraints: "TEXT"),
            .init(key: .stickerId, constraints: "TEXT"),
            .init(key: .sharedUserId, constraints: "TEXT"),
            .init(key: .quoteMessageId, constraints: "TEXT"),
            .init(key: .quoteContent, constraints: "BLOB"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
            .init(key: .albumId, constraints: "TEXT"),
        ]),
        ColumnMigratableTableDefinition<MessageHistory>(constraints: nil, columns: [
            .init(key: .messageId, constraints: "TEXT PRIMARY KEY"),
        ]),
        ColumnMigratableTableDefinition<ParticipantSession>(constraints: "PRIMARY KEY(conversation_id, user_id, session_id)", columns: [
            .init(key: .conversationId, constraints: "TEXT NOT NULL"),
            .init(key: .userId, constraints: "TEXT NOT NULL"),
            .init(key: .sessionId, constraints: "TEXT NOT NULL"),
            .init(key: .sentToServer, constraints: "INTEGER"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
            .init(key: .publicKey, constraints: "TEXT")
        ]),
        ColumnMigratableTableDefinition<Participant>(constraints: "PRIMARY KEY(conversation_id, user_id)", columns: [
            .init(key: .conversationId, constraints: "TEXT NOT NULL"),
            .init(key: .userId, constraints: "TEXT NOT NULL"),
            .init(key: .role, constraints: "TEXT NOT NULL"),
            .init(key: .status, constraints: "INTEGER NOT NULL"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<ResendSessionMessage>(constraints: "PRIMARY KEY(message_id, user_id, session_id)", columns: [
            .init(key: .messageId, constraints: "TEXT NOT NULL"),
            .init(key: .userId, constraints: "TEXT NOT NULL"),
            .init(key: .sessionId, constraints: "TEXT NOT NULL"),
            .init(key: .status, constraints: "INTEGER NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<Snapshot>(constraints: nil, columns: [
            .init(key: .snapshotId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .type, constraints: "TEXT NOT NULL"),
            .init(key: .assetId, constraints: "TEXT NOT NULL"),
            .init(key: .amount, constraints: "TEXT NOT NULL"),
            .init(key: .opponentId, constraints: "TEXT"),
            .init(key: .transactionHash, constraints: "TEXT"),
            .init(key: .sender, constraints: "TEXT"),
            .init(key: .receiver, constraints: "TEXT"),
            .init(key: .memo, constraints: "TEXT"),
            .init(key: .confirmations, constraints: "INTEGER"),
            .init(key: .traceId, constraints: "TEXT"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
            .init(key: .snapshotHash, constraints: "TEXT"),
            .init(key: .openingBalance, constraints: "TEXT NOT NULL DEFAULT ''"),
            .init(key: .closingBalance, constraints: "TEXT NOT NULL DEFAULT ''"),
        ]),
        ColumnMigratableTableDefinition<StickerRelationship>(constraints: "PRIMARY KEY(album_id, sticker_id)", columns: [
            .init(key: .albumId, constraints: "TEXT NOT NULL"),
            .init(key: .stickerId, constraints: "TEXT NOT NULL"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<Sticker>(constraints: nil, columns: [
            .init(key: .stickerId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .assetUrl, constraints: "TEXT NOT NULL"),
            .init(key: .assetType, constraints: "TEXT NOT NULL"),
            .init(key: .assetWidth, constraints: "INTEGER NOT NULL"),
            .init(key: .assetHeight, constraints: "INTEGER NOT NULL"),
            .init(key: .lastUseAt, constraints: "TEXT"),
            .init(key: .albumId, constraints: "TEXT")
        ]),
        ColumnMigratableTableDefinition<TopAsset>(constraints: nil, columns: [
            .init(key: .assetId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .type, constraints: "TEXT NOT NULL"),
            .init(key: .symbol, constraints: "TEXT NOT NULL"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .iconUrl, constraints: "TEXT NOT NULL"),
            .init(key: .balance, constraints: "TEXT NOT NULL"),
            .init(key: .destination, constraints: "TEXT"),
            .init(key: .tag, constraints: "TEXT"),
            .init(key: .priceBtc, constraints: "TEXT NOT NULL"),
            .init(key: .priceUsd, constraints: "TEXT NOT NULL"),
            .init(key: .changeUsd, constraints: "TEXT NOT NULL"),
            .init(key: .chainId, constraints: "TEXT NOT NULL"),
            .init(key: .confirmations, constraints: "INTEGER NOT NULL"),
            .init(key: .assetKey, constraints: "TEXT"),
            .init(key: .reserve, constraints: "TEXT"),
        ]),
        ColumnMigratableTableDefinition<Trace>(constraints: nil, columns: [
            .init(key: .traceId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .assetId, constraints: "TEXT NOT NULL"),
            .init(key: .amount, constraints: "TEXT NOT NULL"),
            .init(key: .opponentId, constraints: "TEXT"),
            .init(key: .destination, constraints: "TEXT"),
            .init(key: .tag, constraints: "TEXT"),
            .init(key: .snapshotId, constraints: "TEXT"),
            .init(key: .createdAt, constraints: "TEXT NOT NULL"),
        ]),
        ColumnMigratableTableDefinition<User>(constraints: nil, columns: [
            .init(key: .userId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .fullName, constraints: "TEXT"),
            .init(key: .biography, constraints: "TEXT"),
            .init(key: .identityNumber, constraints: "TEXT NOT NULL"),
            .init(key: .avatarUrl, constraints: "TEXT"),
            .init(key: .phone, constraints: "TEXT"),
            .init(key: .isVerified, constraints: "INTEGER"),
            .init(key: .muteUntil, constraints: "TEXT"),
            .init(key: .appId, constraints: "TEXT"),
            .init(key: .relationship, constraints: "TEXT NOT NULL"),
            .init(key: .createdAt, constraints: "TEXT"),
            .init(key: .isScam, constraints: "INTEGER"),
        ])
    ]
    
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("wcdb") { db in
            var localVersion = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
            if localVersion == 0 {
                localVersion = DatabaseUserDefault.shared.mixinDatabaseVersion
            }
            
            guard localVersion > 0 else {
                return
            }
            
            if localVersion < 8 {
                try db.execute(sql: "DROP TABLE IF EXISTS sent_sender_keys")
                try db.execute(sql: "DROP INDEX IF EXISTS jobs_next_indexs")
            }
            
            if localVersion < 9 {
                try db.execute(sql: "DROP TABLE IF EXISTS resend_messages")
            }
            
            if try db.tableExists("participant_session") && localVersion < 11 {
                try db.execute(sql: "DELETE FROM participant_session WHERE ifnull(session_id,'') == ''")
            }
            
            if localVersion < 15 {
                try db.execute(sql: "DROP TRIGGER IF EXISTS conversation_unseen_message_count_insert")
            }
            
            if localVersion < 18 {
                try db.execute(sql: "DROP INDEX IF EXISTS jobs_next_indexs")
            }
        }
        
        migrator.registerMigration("create_table") { db in
            for table in self.tableMigrations {
                try self.migrateTable(with: table, into: db)
            }
            
            // Some of the indices needs renaming but we can't do it now.
            // In some rare cases the database file corrupts, then we rebuild
            // it by dropping the grdb_migrations table and migrate again.
            // These indices can be renamed after a better repair method is implemented
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS conversations_indexs ON conversations(pin_time, last_message_created_at)")
            
            try db.execute(sql: "CREATE UNIQUE INDEX IF NOT EXISTS jobs_index_id ON jobs(job_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS jobs_next_indexs ON jobs(category, priority DESC, orderId ASC)")
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS messages_page_indexs ON messages(conversation_id, created_at)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_messages_category ON messages(conversation_id, category)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_messages_quote ON messages(conversation_id, quote_message_id)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_messages_pick ON messages(conversation_id, status, user_id, created_at)")
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS message_mentions_conversation_indexs ON message_mentions(conversation_id, has_read)")
        }
        
        migrator.registerMigration("fts5_v3_2") { (db) in
            try db.execute(sql: "DROP TABLE IF EXISTS messages_fts")
            if !AppGroupUserDefaults.Database.isFTSInitialized {
                // We found a new way to intialize FTS content with better performance
                // It does not affect fts5_v3 table which is completely intialized
                // Only drop the table for uncompleted ones
                try db.execute(sql: "DROP TABLE IF EXISTS \(Message.ftsTableName)")
            }
            try db.create(virtualTable: Message.ftsTableName, ifNotExists: true, using: FTS5()) { t in
                t.tokenizer = MixinTokenizer.tokenizerDescriptor()
                t.column(Message.column(of: .conversationId).name)
                t.column(Message.column(of: .userId).name)
                t.column(Message.column(of: .messageId).name)
                t.column(Message.column(of: .content).name)
                t.column(Message.column(of: .createdAt).name)
                t.column("reserved1")
                t.column("reserved2")
            }
        }
        
        migrator.registerMigration("index_optimization_1") { (db) in
            try db.execute(sql: "DROP INDEX IF EXISTS users_app_indexs")
            try db.execute(sql: "DROP INDEX IF EXISTS users_identity_number_indexs")
            
            try db.execute(sql: "DROP INDEX IF EXISTS messages_category_indexs")
            try db.execute(sql: "DROP INDEX IF EXISTS messages_pending_indexs")
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_messages_category ON messages(conversation_id, category)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_messages_quote ON messages(conversation_id, quote_message_id)")
        }
        
        migrator.registerMigration("transcript") { (db) in
            let sql = """
                CREATE TABLE IF NOT EXISTS transcript_messages(
                    transcript_id TEXT NOT NULL,
                    message_id TEXT NOT NULL,
                    user_id TEXT,
                    user_full_name TEXT,
                    category TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    content TEXT,
                    media_url TEXT,
                    media_name TEXT,
                    media_size INTEGER,
                    media_width INTEGER,
                    media_height INTEGER,
                    media_mime_type TEXT,
                    media_duration INTEGER,
                    media_status TEXT,
                    media_waveform BLOB,
                    thumb_image TEXT,
                    thumb_url TEXT,
                    media_key BLOB,
                    media_digest BLOB,
                    media_created_at TEXT,
                    sticker_id TEXT,
                    shared_user_id TEXT,
                    mentions TEXT,
                    quote_id TEXT,
                    quote_content TEXT,
                    caption TEXT,
                    PRIMARY KEY (transcript_id, message_id)
                )
            """
            try db.execute(sql: sql)
        }
        
        migrator.registerMigration("pin_messages") { db in
            let sql =  """
                CREATE TABLE IF NOT EXISTS pin_messages(
                    message_id TEXT NOT NULL,
                    conversation_id TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    PRIMARY KEY (message_id)
                )
            """
            try db.execute(sql: sql)
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_pin_messages_conversation_id ON pin_messages(conversation_id)")
        }
        
        migrator.registerMigration("encrypted_app_messages") { (db) in
            let infos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(participant_session)")
            let columnNames = infos.map(\.name)
            if !columnNames.contains("public_key") {
                try db.execute(sql: "ALTER TABLE participant_session ADD COLUMN public_key TEXT")
            }
        }
        
        migrator.registerMigration("index_optimization_2") { (db) in
            try db.execute(sql: "DROP INDEX IF EXISTS messages_unread_indexs")
            try db.execute(sql: "DROP INDEX IF EXISTS messages_user_indexs")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS index_messages_pick ON messages(conversation_id, status, user_id, created_at)")
        }
        
        migrator.registerMigration("stickers_store_1") { db in
            let albumInfos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(albums)")
            let albumColumnNames = albumInfos.map(\.name)
            if !albumColumnNames.contains("banner") {
                try db.execute(sql: "ALTER TABLE albums ADD COLUMN banner TEXT")
            }
            if !albumColumnNames.contains("added") {
                try db.execute(sql: "ALTER TABLE albums ADD COLUMN added INTEGER NOT NULL DEFAULT 0")
                try db.execute(sql: "UPDATE albums SET added = 1")
            }
            if !albumColumnNames.contains("ordered_at") {
                try db.execute(sql: "ALTER TABLE albums ADD COLUMN ordered_at INTEGER NOT NULL DEFAULT 0")
                let albums = try Album
                    .order(Album.column(of: .updatedAt).asc)
                    .fetchAll(db)
                for (index, album) in albums.enumerated() {
                    try Album
                        .filter(Album.column(of: .albumId) == album.albumId)
                        .updateAll(db, [Album.column(of: .orderedAt).set(to: index)])
                }
            }
            let messageInfos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(messages)")
            if !messageInfos.map(\.name).contains("album_id") {
                try db.execute(sql: "ALTER TABLE messages ADD COLUMN album_id TEXT")
            }
            let stickerInfos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(stickers)")
            if !stickerInfos.map(\.name).contains("album_id") {
                try db.execute(sql: "ALTER TABLE stickers ADD COLUMN album_id TEXT")
            }
        }
        
        migrator.registerMigration("properties") { db in
            try db.execute(sql: "CREATE TABLE IF NOT EXISTS properties (key TEXT NOT NULL, value TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(key))")
        }
        
        migrator.registerMigration("albums") { db in
            let albumInfos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(albums)")
            if !albumInfos.map(\.name).contains("is_verified") {
                try db.execute(sql: "ALTER TABLE albums ADD COLUMN is_verified INTEGER NOT NULL DEFAULT 0")
                try db.execute(sql: "UPDATE albums SET update_at = ''")
            }
        }
        
        migrator.registerMigration("expired_messages") { db in
            let sql =  """
                CREATE TABLE IF NOT EXISTS expired_messages(
                    message_id TEXT NOT NULL,
                    expire_in INTEGER NOT NULL,
                    expire_at INTEGER,
                    PRIMARY KEY (message_id)
                )
            """
            try db.execute(sql: sql)
            
            let conversations = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(conversations)")
            if !conversations.map(\.name).contains("expire_in") {
                try db.execute(sql: "ALTER TABLE conversations ADD COLUMN expire_in INTEGER")
            }
        }
        
        migrator.registerMigration("deposit_entries") { db in
            let assets = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(assets)")
            if !assets.map(\.name).contains("deposit_entries") {
                try db.execute(sql: "ALTER TABLE assets ADD COLUMN deposit_entries TEXT")
            }
        }
        
        migrator.registerMigration("deposit_entries_2") { db in
            let assetsColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(assets)").map(\.name)
            if !assetsColumns.contains("destination") {
                try db.execute(sql: "ALTER TABLE assets ADD COLUMN destination TEXT")
            }
            if !assetsColumns.contains("tag") {
                try db.execute(sql: "ALTER TABLE assets ADD COLUMN tag TEXT")
            }
            
            let topAssetsColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(top_assets)").map(\.name)
            if !topAssetsColumns.contains("destination") {
                try db.execute(sql: "ALTER TABLE top_assets ADD COLUMN destination TEXT")
            }
            if !topAssetsColumns.contains("tag") {
                try db.execute(sql: "ALTER TABLE top_assets ADD COLUMN tag TEXT")
            }
        }
        
        migrator.registerMigration("drop_drigger") { db in
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversation_last_message_update")
            try db.execute(sql: "DROP TRIGGER IF EXISTS conversation_last_message_delete")
        }
        
        migrator.registerMigration("chains") { db in
            let sql =  """
                CREATE TABLE IF NOT EXISTS chains(
                    chain_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    symbol TEXT NOT NULL,
                    icon_url TEXT NOT NULL,
                    threshold INTEGER NOT NULL,
                    PRIMARY KEY (chain_id)
                )
            """
            try db.execute(sql: sql)
        }
        
        migrator.registerMigration("snapshot") { db in
            let columns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(snapshots)").map(\.name)
            if !columns.contains("snapshot_hash") {
                try db.execute(sql: "ALTER TABLE snapshots ADD COLUMN snapshot_hash TEXT")
            }
            if !columns.contains("opening_balance") {
                try db.execute(sql: "ALTER TABLE snapshots ADD COLUMN opening_balance TEXT NOT NULL DEFAULT ''")
            }
            if !columns.contains("closing_balance") {
                try db.execute(sql: "ALTER TABLE snapshots ADD COLUMN closing_balance TEXT NOT NULL DEFAULT ''")
            }
        }
        
        migrator.registerMigration("conversation_created_at") { db in
            let columns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(conversations)").map(\.name)
            if !columns.contains("created_at") {
                try db.execute(sql: "ALTER TABLE conversations ADD COLUMN created_at TEXT NOT NULL DEFAULT ''")
            }
        }
        
        migrator.registerMigration("deactivated_user") { db in
            let columns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(users)").map(\.name)
            if !columns.contains("is_deactivated") {
                try db.execute(sql: "ALTER TABLE users ADD COLUMN is_deactivated INTEGER")
            }
        }
        
        migrator.registerMigration("withdrawal_memo") { db in
            let assetColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(assets)").map(\.name)
            if !assetColumns.contains("withdrawal_memo_possibility") {
                try db.execute(sql: "ALTER TABLE assets ADD COLUMN withdrawal_memo_possibility TEXT")
            }
            
            let topAssetColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(top_assets)").map(\.name)
            if !topAssetColumns.contains("withdrawal_memo_possibility") {
                try db.execute(sql: "ALTER TABLE top_assets ADD COLUMN withdrawal_memo_possibility TEXT")
            }
        }
        
        migrator.registerMigration("utxo") { db in
            let sqls = [
                """
                CREATE TABLE IF NOT EXISTS `outputs` (
                    `output_id` TEXT NOT NULL,
                    `transaction_hash` TEXT NOT NULL,
                    `output_index` INTEGER NOT NULL,
                    `asset` TEXT NOT NULL,
                    `amount` TEXT NOT NULL,
                    `mask` TEXT NOT NULL,
                    `keys` TEXT NOT NULL,
                    `receivers` TEXT NOT NULL,
                    `receivers_hash` TEXT NOT NULL,
                    `receivers_threshold` INTEGER NOT NULL,
                    `extra` TEXT NOT NULL,
                    `state` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    `signed_by` TEXT NOT NULL,
                    `signed_at` TEXT NOT NULL,
                    `spent_at` TEXT NOT NULL,
                    `sequence`  INTEGER NOT NULL,
                    PRIMARY KEY(`output_id`)
                )
                """,
                
                """
                CREATE TABLE IF NOT EXISTS `tokens` (
                    `asset_id` TEXT NOT NULL,
                    `kernel_asset_id` TEXT NOT NULL,
                    `symbol` TEXT NOT NULL,
                    `name` TEXT NOT NULL,
                    `icon_url` TEXT NOT NULL,
                    `price_btc` TEXT NOT NULL,
                    `price_usd` TEXT NOT NULL,
                    `chain_id` TEXT NOT NULL,
                    `change_usd` TEXT NOT NULL,
                    `change_btc` TEXT NOT NULL,
                    `dust` TEXT NOT NULL,
                    `confirmations` INTEGER NOT NULL,
                    `asset_key` TEXT NOT NULL,
                    PRIMARY KEY(`asset_id`)
                )
                """,
                
                """
                CREATE TABLE IF NOT EXISTS `tokens_extra` (
                    `asset_id` TEXT NOT NULL,
                    `kernel_asset_id` TEXT NOT NULL,
                    `hidden` INTEGER,
                    `balance` TEXT,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(`asset_id`)
                )
                """,
                
                """
                CREATE TABLE IF NOT EXISTS `safe_snapshots` (
                    `snapshot_id` TEXT NOT NULL,
                    `type` TEXT NOT NULL,
                    `asset_id` TEXT NOT NULL,
                    `amount` TEXT NOT NULL,
                    `user_id` TEXT NOT NULL,
                    `opponent_id` TEXT NOT NULL,
                    `memo` TEXT NOT NULL,
                    `transaction_hash` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    `trace_id` TEXT,
                    `confirmations` INTEGER,
                    `opening_balance` TEXT,
                    `closing_balance` TEXT,
                    PRIMARY KEY(`snapshot_id`)
                )
                """,
                
                """
                CREATE TABLE IF NOT EXISTS `deposit_entries` (
                    `entry_id` TEXT NOT NULL,
                    `chain_id` TEXT NOT NULL,
                    `is_primary` INTEGER NOT NULL,
                    `members` TEXT NOT NULL,
                    `destination` TEXT NOT NULL,
                    `tag` TEXT,
                    `signature` TEXT NOT NULL,
                    `threshold` INTEGER NOT NULL,
                    PRIMARY KEY(`entry_id`)
                )
                """,
                
                """
                CREATE TABLE IF NOT EXISTS `raw_transactions` (
                    `request_id` TEXT NOT NULL,
                    `raw_transaction` TEXT NOT NULL,
                    `receiver_id` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    PRIMARY KEY(`request_id`)
                )
                """,
                
                "CREATE UNIQUE INDEX IF NOT EXISTS `index_outputs_transaction_hash_output_index` ON `outputs` (`transaction_hash`, `output_index`)",
                "CREATE INDEX IF NOT EXISTS `index_tokens_kernel_asset_id` ON `tokens` (`kernel_asset_id`)",
                "CREATE INDEX IF NOT EXISTS `index_tokens_extra_kernel_asset_id` ON `tokens_extra` (`kernel_asset_id`)",
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
            
            let infos = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(chains)")
            let columnNames = infos.map(\.name)
            if !columnNames.contains("withdrawal_memo_possibility") {
                try db.execute(sql: "ALTER TABLE chains ADD COLUMN withdrawal_memo_possibility TEXT NOT NULL DEFAULT 'possible'")
            }
        }
        
        migrator.registerMigration("utxo_2") { db in
            let columns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(safe_snapshots)").map(\.name)
            if !columns.contains("deposit") {
                try db.execute(sql: "ALTER TABLE safe_snapshots ADD COLUMN deposit TEXT")
            }
            if !columns.contains("withdrawal") {
                try db.execute(sql: "ALTER TABLE safe_snapshots ADD COLUMN withdrawal TEXT")
            }
            
            try db.execute(sql: "DROP INDEX IF EXISTS `index_outputs_asset_state_created_at`")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS `index_outputs_asset_state_sequence` ON `outputs` (`asset`, `state`, `sequence`)")
        }
        
        migrator.registerMigration("utxo_3") { db in
            let columns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(raw_transactions)").map(\.name)
            if !columns.contains("state") {
                try db.execute(sql: "ALTER TABLE `raw_transactions` ADD COLUMN `state` TEXT NOT NULL DEFAULT 'unspent'")
            }
            if !columns.contains("type") {
                try db.execute(sql: "ALTER TABLE `raw_transactions` ADD COLUMN `type` INTEGER NOT NULL DEFAULT 0")
            }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS `index_raw_transactions_state_type` ON `raw_transactions` (`state`, `type`)")
        }
        
        migrator.registerMigration("inscription") { db in
            let outputsColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(outputs)").map(\.name)
            if !outputsColumns.contains("inscription_hash") {
                try db.execute(sql: "ALTER TABLE `outputs` ADD COLUMN `inscription_hash` TEXT")
            }
            
            let tokensColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(tokens)").map(\.name)
            if !tokensColumns.contains("collection_hash") {
                try db.execute(sql: "ALTER TABLE `tokens` ADD COLUMN `collection_hash` TEXT")
            }
            
            let snapshotColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(safe_snapshots)").map(\.name)
            if !snapshotColumns.contains("inscription_hash") {
                try db.execute(sql: "ALTER TABLE `safe_snapshots` ADD COLUMN `inscription_hash` TEXT")
            }
            
            let sqls = [
                """
                CREATE TABLE IF NOT EXISTS `inscription_collections` (
                    `collection_hash` TEXT NOT NULL,
                    `supply` TEXT NOT NULL,
                    `unit` TEXT NOT NULL,
                    `symbol` TEXT NOT NULL,
                    `name` TEXT NOT NULL,
                    `icon_url` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(`collection_hash`)
                )
                """,
                
                """
                CREATE TABLE IF NOT EXISTS `inscription_items` (
                    `inscription_hash` TEXT NOT NULL,
                    `collection_hash` TEXT NOT NULL,
                    `sequence` INTEGER NOT NULL,
                    `content_type` TEXT NOT NULL,
                    `content_url` TEXT NOT NULL,
                    `occupied_by` TEXT,
                    `occupied_at` TEXT,
                    `created_at` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(`inscription_hash`)
                )
                """,
                
                "CREATE INDEX IF NOT EXISTS `index_outputs_inscription_hash` ON `outputs` (`inscription_hash`) WHERE `inscription_hash` IS NOT NULL",
                "CREATE INDEX IF NOT EXISTS `index_tokens_collection_hash` ON `tokens` (`collection_hash`) WHERE `collection_hash` IS NOT NULL",
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("inscription_2") { db in
            let itemColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(inscription_items)").map(\.name)
            if !itemColumns.contains("traits") {
                try db.execute(sql: "ALTER TABLE `inscription_items` ADD COLUMN `traits` TEXT")
            }
            if !itemColumns.contains("owner") {
                try db.execute(sql: "ALTER TABLE `inscription_items` ADD COLUMN `owner` TEXT")
            }
            
            let collectionColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(inscription_collections)").map(\.name)
            if !collectionColumns.contains("description") {
                try db.execute(sql: "ALTER TABLE `inscription_collections` ADD COLUMN `description` TEXT")
            }
        }
        
        migrator.registerMigration("membership") { db in
            let itemColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(users)").map(\.name)
            if !itemColumns.contains("membership") {
                try db.execute(sql: "ALTER TABLE `users` ADD COLUMN `membership` TEXT")
            }
        }
        
        migrator.registerMigration("market_2") { db in
            let sqls = [
                "DROP TABLE IF EXISTS `markets`",
                """
                CREATE TABLE IF NOT EXISTS `markets` (
                    `coin_id` TEXT NOT NULL,
                    `name` TEXT NOT NULL,
                    `symbol` TEXT NOT NULL,
                    `icon_url` TEXT NOT NULL,
                    `current_price` TEXT NOT NULL,
                    `market_cap` TEXT NOT NULL,
                    `market_cap_rank` TEXT NOT NULL,
                    `total_volume` TEXT NOT NULL,
                    `high_24h` TEXT NOT NULL,
                    `low_24h` TEXT NOT NULL,
                    `price_change_24h` TEXT NOT NULL,
                    `price_change_percentage_1h` TEXT NOT NULL,
                    `price_change_percentage_24h` TEXT NOT NULL,
                    `price_change_percentage_7d` TEXT NOT NULL,
                    `price_change_percentage_30d` TEXT NOT NULL,
                    `market_cap_change_24h` TEXT NOT NULL,
                    `market_cap_change_percentage_24h` TEXT NOT NULL,
                    `circulating_supply` TEXT NOT NULL,
                    `total_supply` TEXT NOT NULL,
                    `max_supply` TEXT NOT NULL,
                    `ath` TEXT NOT NULL,
                    `ath_change_percentage` TEXT NOT NULL,
                    `ath_date` TEXT NOT NULL,
                    `atl` TEXT NOT NULL,
                    `atl_change_percentage` TEXT NOT NULL,
                    `atl_date` TEXT NOT NULL,
                    `asset_ids` TEXT,
                    `sparkline_in_7d` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(`coin_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `market_ids` (
                    `coin_id` TEXT NOT NULL,
                    `asset_id` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    PRIMARY KEY(`coin_id`, `asset_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `market_favored` (
                    `coin_id` TEXT NOT NULL,
                    `is_favored` INTEGER NOT NULL,
                    `created_at` TEXT NOT NULL,
                    PRIMARY KEY(`coin_id`)
                )
                """,
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("market_3") { db in
            let sqls = [
                "DROP TABLE IF EXISTS `history_prices`",
                """
                CREATE TABLE IF NOT EXISTS `history_prices` (
                    `coin_id` TEXT NOT NULL,
                    `type` TEXT NOT NULL,
                    `data` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(`coin_id`, `type`)
                )
                """,
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("index_optimization_safe_snapshots") { db in
            let sqls = [
                "CREATE INDEX IF NOT EXISTS index_safe_snapshots_created_at ON safe_snapshots(created_at)",
                "CREATE INDEX IF NOT EXISTS index_safe_snapshots_pending ON safe_snapshots(type, asset_id)",
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("market_alerts") { db in
            let sqls = [
                """
                CREATE TABLE IF NOT EXISTS `market_cap_ranks` (
                    `coin_id` TEXT NOT NULL,
                    `market_cap_rank` TEXT NOT NULL,
                    `updated_at` TEXT NOT NULL,
                    PRIMARY KEY(`coin_id`)
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS `market_alerts` (
                    `alert_id` TEXT NOT NULL,
                    `coin_id` TEXT NOT NULL,
                    `type` TEXT NOT NULL,
                    `frequency` TEXT NOT NULL,
                    `status` TEXT NOT NULL,
                    `value` TEXT NOT NULL,
                    `created_at` TEXT NOT NULL,
                    PRIMARY KEY(`alert_id`)
                )
                """
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("update_participant_session_bad_data") { db in
            let sql = """
            UPDATE participant_session SET sent_to_server = NULL
            WHERE conversation_id IN (
                SELECT conversation_id FROM participant_session 
                GROUP BY conversation_id 
                HAVING COUNT(conversation_id) > 384
            )
            """
            try db.execute(sql: sql)
        }
        
        migrator.registerMigration("market_24h") { db in
            let sql = "ALTER TABLE `markets` ADD COLUMN `sparkline_in_24h` TEXT NOT NULL DEFAULT ''"
            try db.execute(sql: sql)
        }
        
        migrator.registerMigration("swap_orders") { db in
            let sql = """
            CREATE TABLE IF NOT EXISTS `swap_orders` (
                `order_id` TEXT NOT NULL,
                `user_id` TEXT NOT NULL,
                `pay_asset_id` TEXT NOT NULL,
                `receive_asset_id` TEXT NOT NULL,
                `pay_amount` TEXT NOT NULL,
                `receive_amount` TEXT NOT NULL,
                `pay_trace_id` TEXT NOT NULL,
                `receive_trace_id` TEXT NOT NULL,
                `state` TEXT NOT NULL,
                `created_at` TEXT NOT NULL,
                `order_type` TEXT NOT NULL,
                PRIMARY KEY(`order_id`)
            )
            """
            try db.execute(sql: sql)
        }
        
        migrator.registerMigration("addresses_chain") { db in
            let itemColumns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(addresses)").map(\.name)
            if !itemColumns.contains("chain_id") {
                try db.execute(sql: "DELETE FROM `addresses`")
                try db.execute(sql: "ALTER TABLE `addresses` ADD COLUMN `chain_id` TEXT NOT NULL DEFAULT ''")
            }
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS `index_addresses_chain_id_updated_at` ON `addresses` (`chain_id`, `updated_at`)")
        }
        
        migrator.registerMigration("membership_orders_2") { db in
            let sqls = [
                "DROP TABLE IF EXISTS membership_orders",
                """
                CREATE TABLE IF NOT EXISTS `membership_orders` (
                    `order_id`          TEXT NOT NULL,
                    `category`          TEXT NOT NULL,
                    `amount`            TEXT NOT NULL,
                    `amount_actual`     TEXT NOT NULL,
                    `amount_original`   TEXT NOT NULL,
                    `after`             TEXT NOT NULL,
                    `before`            TEXT NOT NULL,
                    `created_at`        TEXT NOT NULL,
                    `fiat_order`        TEXT,
                    `stars`             INTEGER NOT NULL,
                    `payment_url`       TEXT,
                    `status`            TEXT NOT NULL,
                    PRIMARY KEY(order_id)
                )
                """,
                "CREATE INDEX IF NOT EXISTS index_membership_orders_created_at ON membership_orders(created_at)",
            ]
            for sql in sqls {
                try db.execute(sql: sql)
            }
        }
        
        migrator.registerMigration("tokens_precision") { db in
            let columns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(tokens)").map(\.name)
            if !columns.contains("precision") {
                try db.execute(sql: "ALTER TABLE `tokens` ADD COLUMN `precision` INTEGER NOT NULL DEFAULT \(MixinToken.invalidPrecision)")
            }
        }
        
        migrator.registerMigration("deposit_entries_3") { db in
            let columns = try TableInfo.fetchAll(db, sql: "PRAGMA table_info(deposit_entries)").map(\.name)
            let hasMinimum = columns.contains("minimum")
            let hasMaximum = columns.contains("maximum")
            if !hasMinimum || !hasMaximum {
                try db.execute(sql: "DELETE FROM `deposit_entries`")
                if !hasMinimum {
                    try db.execute(sql: "ALTER TABLE `deposit_entries` ADD COLUMN `minimum` TEXT NOT NULL")
                }
                if !hasMaximum {
                    try db.execute(sql: "ALTER TABLE `deposit_entries` ADD COLUMN `maximum` TEXT NOT NULL")
                }
            }
        }
        
        return migrator
    }
    
    public override func tableDidLose(with error: Error?, fileSize: Int64?, fileCreationDate: Date?) {
        let error: MixinServicesError = .databaseCorrupted(database: "user",
                                                           isAppExtension: isAppExtension,
                                                           error: error,
                                                           fileSize: fileSize,
                                                           fileCreationDate: fileCreationDate)
        reporter.report(error: error)
        Logger.database.error(category: "UserDatabase", message: "Table lost with error: \(error)")
        AppGroupUserDefaults.User.needsRebuildDatabase = true
    }
    
}

extension UserDatabase {
    
    public static func reloadCurrent(with db: UserDatabase? = nil) {
        current = db ?? makeDatabaseWithDefaultLocation()
        current.migrate()
    }
    
    public static func closeCurrent() {
        autoreleasepool {
            current = nil
        }
    }
    
    private static func makeDatabaseWithDefaultLocation() -> UserDatabase {
        let db = try! UserDatabase(url: AppGroupContainer.userDatabaseUrl)
        if AppGroupUserDefaults.User.needsRebuildDatabase {
            try? db.pool.barrierWriteWithoutTransaction { (db) -> Void in
                try db.execute(sql: "DROP TABLE IF EXISTS grdb_migrations")
            }
        }
        return db
    }
    
}

extension UserDatabase {
    
    public func clearSentSenderKey(sessionID: String) {
        try! pool.barrierWriteWithoutTransaction { (db) -> Void in
            try db.execute(sql: "UPDATE participant_session SET sent_to_server = NULL")
            try db.execute(sql: "DELETE FROM participant_session WHERE session_id = ?", arguments: [sessionID])
        }
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
