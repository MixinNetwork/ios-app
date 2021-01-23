import GRDB

public final class UserDatabase: Database {
    
    public private(set) static var current: UserDatabase! = loadCurrent()
    
    public override class var config: Configuration {
        var config = super.config
        config.label = "User"
        config.foreignKeysEnabled = false
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
    
    internal lazy var tableMigrations: [ColumnMigratable] = [
        ColumnMigratableTableDefinition<Address>(constraints: nil, columns: [
            .init(key: .type, constraints: "TEXT NOT NULL"),
            .init(key: .addressId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .assetId, constraints: "TEXT NOT NULL"),
            .init(key: .destination, constraints: "TEXT NOT NULL"),
            .init(key: .label, constraints: "TEXT NOT NULL"),
            .init(key: .tag, constraints: "TEXT"),
            .init(key: .fee, constraints: "TEXT NOT NULL"),
            .init(key: .reserve, constraints: "TEXT"),
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
        ]),
        ColumnMigratableTableDefinition<App>(constraints: nil, columns: [
            .init(key: .appId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .appNumber, constraints: "TEXT NOT NULL"),
            .init(key: .redirectUri, constraints: "TEXT NOT NULL"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .category, constraints: "TEXT NOT NULL"),
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
            .init(key: .destination, constraints: "TEXT NOT NULL"),
            .init(key: .tag, constraints: "TEXT"),
            .init(key: .priceBtc, constraints: "TEXT NOT NULL"),
            .init(key: .priceUsd, constraints: "TEXT NOT NULL"),
            .init(key: .changeUsd, constraints: "TEXT NOT NULL"),
            .init(key: .chainId, constraints: "TEXT NOT NULL"),
            .init(key: .confirmations, constraints: "INTEGER NOT NULL"),
            .init(key: .assetKey, constraints: "TEXT"),
            .init(key: .reserve, constraints: "TEXT"),
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
            .init(key: .category, constraints: "TEXT NOT NULL"),
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
        ]),
        ColumnMigratableTableDefinition<TopAsset>(constraints: nil, columns: [
            .init(key: .assetId, constraints: "TEXT PRIMARY KEY"),
            .init(key: .type, constraints: "TEXT NOT NULL"),
            .init(key: .symbol, constraints: "TEXT NOT NULL"),
            .init(key: .name, constraints: "TEXT NOT NULL"),
            .init(key: .iconUrl, constraints: "TEXT NOT NULL"),
            .init(key: .balance, constraints: "TEXT NOT NULL"),
            .init(key: .destination, constraints: "TEXT NOT NULL"),
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
        
        migrator.registerMigration("fts5") { (db) in
            try db.create(virtualTable: Message.ftsTableName, ifNotExists: true, using: FTS5()) { t in
                t.tokenizer = MixinTokenizer.tokenizerDescriptor()
                t.column(Message.column(of: .messageId).name).notIndexed()
                t.column(Message.column(of: .conversationId).name).notIndexed()
                t.column(Message.column(of: .content).name)
                t.column(Message.column(of: .name).name)
            }
        }
        
        return migrator
    }
    
}

extension UserDatabase {
    
    public static func reloadCurrent() {
        current = loadCurrent()
    }
    
    internal static func closeCurrent() {
        current = nil
    }
    
    private static func loadCurrent() -> UserDatabase {
        let db = try! UserDatabase(url: AppGroupContainer.userDatabaseUrl)
        if AppGroupUserDefaults.User.needsRebuildDatabase {
            try? db.pool.barrierWriteWithoutTransaction { (db) -> Void in
                try db.execute(sql: "DROP TABLE IF EXISTS grdb_migrations")
            }
        }
        db.migrate()
        return db
    }
    
}

extension UserDatabase {
    
    public func clearSentSenderKey() {
        try! pool.barrierWriteWithoutTransaction { (db) -> Void in
            try ParticipantSession.updateAll(db, [ParticipantSession.column(of: .sentToServer).set(to: nil)])
        }
    }
    
    private func migrate() {
        try! migrator.migrate(pool)
    }
    
}
