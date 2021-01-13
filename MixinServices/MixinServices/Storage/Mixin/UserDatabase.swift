import GRDB

public final class UserDatabase: Database {
    
    public private(set) static var current: UserDatabase! = loadCurrent()
    
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
            
            if try db.tableExists("assets") && localVersion < 21 {
                try db.execute(sql: "UPDATE assets SET reserve = '0'")
            }
            
            if try db.tableExists("top_assets") && localVersion < 21 {
                try db.execute(sql: "UPDATE top_assets SET reserve = '0'")
            }
        }
        
        migrator.registerMigration("create_table") { db in
            let addresses = TableDefinition<Address>(constraints: nil, columns: [
                .init(key: .type, constraints: "TEXT"),
                .init(key: .addressId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .assetId, constraints: "TEXT"),
                .init(key: .destination, constraints: "TEXT"),
                .init(key: .label, constraints: "TEXT"),
                .init(key: .tag, constraints: "TEXT"),
                .init(key: .fee, constraints: "TEXT"),
                .init(key: .reserve, constraints: "TEXT"),
                .init(key: .dust, constraints: "TEXT"),
                .init(key: .updatedAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: addresses, into: db)
            
            let albums = TableDefinition<Album>(constraints: nil, columns: [
                .init(key: .albumId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .name, constraints: "TEXT"),
                .init(key: .iconUrl, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
                .init(key: .updatedAt, constraints: "TEXT"),
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .category, constraints: "TEXT"),
                .init(key: .description, constraints: "TEXT"),
            ])
            try self.migrateTable(with: albums, into: db)
            
            let apps = TableDefinition<App>(constraints: nil, columns: [
                .init(key: .appId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .appNumber, constraints: "TEXT"),
                .init(key: .redirectUri, constraints: "TEXT"),
                .init(key: .name, constraints: "TEXT"),
                .init(key: .category, constraints: "TEXT"),
                .init(key: .iconUrl, constraints: "TEXT"),
                .init(key: .capabilities, constraints: "BLOB"),
                .init(key: .resourcePatterns, constraints: "BLOB"),
                .init(key: .homeUri, constraints: "TEXT"),
                .init(key: .creatorId, constraints: "TEXT"),
                .init(key: .updatedAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: apps, into: db)
            
            let assets = TableDefinition<Asset>(constraints: nil, columns: [
                .init(key: .assetId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .type, constraints: "TEXT"),
                .init(key: .symbol, constraints: "TEXT"),
                .init(key: .name, constraints: "TEXT"),
                .init(key: .iconUrl, constraints: "TEXT"),
                .init(key: .balance, constraints: "TEXT"),
                .init(key: .destination, constraints: "TEXT"),
                .init(key: .tag, constraints: "TEXT"),
                .init(key: .priceBtc, constraints: "TEXT"),
                .init(key: .priceUsd, constraints: "TEXT"),
                .init(key: .changeUsd, constraints: "TEXT"),
                .init(key: .chainId, constraints: "TEXT"),
                .init(key: .confirmations, constraints: "INTEGER"),
                .init(key: .assetKey, constraints: "TEXT"),
                .init(key: .reserve, constraints: "TEXT"),
            ])
            try self.migrateTable(with: assets, into: db)
            
            let circleConversations = TableDefinition<CircleConversation>(constraints: "PRIMARY KEY(conversation_id, circle_id)", columns: [
                .init(key: .circleId, constraints: "TEXT"),
                .init(key: .conversationId, constraints: "TEXT"),
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
                .init(key: .pinTime, constraints: "TEXT"),
            ])
            try self.migrateTable(with: circleConversations, into: db)
            
            let circles = TableDefinition<Circle>(constraints: nil, columns: [
                .init(key: .circleId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .name, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: circles, into: db)
            
            let conversations = TableDefinition<Conversation>(constraints: nil, columns: [
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
                .init(key: .status, constraints: "INTEGER"),
                .init(key: .draft, constraints: "TEXT"),
                .init(key: .muteUntil, constraints: "TEXT"),
                .init(key: .codeUrl, constraints: "TEXT"),
                .init(key: .pinTime, constraints: "TEXT"),
            ])
            try self.migrateTable(with: conversations, into: db)
            
            let favoriteApps = TableDefinition<FavoriteApp>(constraints: "PRIMARY KEY(user_id, app_id)", columns: [
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .appId, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: favoriteApps, into: db)
            
            let jobs = TableDefinition<Job>(constraints: nil, columns: [
                .init(key: .orderId, constraints: "INTEGER PRIMARY KEY AUTOINCREMENT"),
                .init(key: .jobId, constraints: "TEXT"),
                .init(key: .priority, constraints: "INTEGER"),
                .init(key: .blazeMessage, constraints: "BLOB"),
                .init(key: .blazeMessageData, constraints: "BLOB"),
                .init(key: .action, constraints: "TEXT"),
                .init(key: .category, constraints: "TEXT"),
                .init(key: .conversationId, constraints: "TEXT"),
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .resendMessageId, constraints: "TEXT"),
                .init(key: .messageId, constraints: "TEXT"),
                .init(key: .status, constraints: "TEXT"),
                .init(key: .sessionId, constraints: "TEXT"),
            ])
            try self.migrateTable(with: jobs, into: db)
            
            let messageMentions = TableDefinition<MessageMention>(constraints: nil, columns: [
                .init(key: .messageId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .conversationId, constraints: "TEXT"),
                .init(key: .mentionsJson, constraints: "BLOB"),
                .init(key: .hasRead, constraints: "INTEGER"),
            ])
            try self.migrateTable(with: messageMentions, into: db)
            
            let messages = TableDefinition<Message>(constraints: nil, columns: [
                .init(key: .messageId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .conversationId, constraints: "TEXT"),
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .category, constraints: "TEXT"),
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
                .init(key: .status, constraints: "TEXT"),
                .init(key: .action, constraints: "TEXT"),
                .init(key: .participantId, constraints: "TEXT"),
                .init(key: .snapshotId, constraints: "TEXT"),
                .init(key: .name, constraints: "TEXT"),
                .init(key: .stickerId, constraints: "TEXT"),
                .init(key: .sharedUserId, constraints: "TEXT"),
                .init(key: .quoteMessageId, constraints: "TEXT"),
                .init(key: .quoteContent, constraints: "BLOB"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: messages, into: db)
            
            let messageHistory = TableDefinition<MessageHistory>(constraints: nil, columns: [
                .init(key: .messageId, constraints: "TEXT PRIMARY KEY"),
            ])
            try self.migrateTable(with: messageHistory, into: db)
            
            let participantSession = TableDefinition<ParticipantSession>(constraints: "PRIMARY KEY(conversation_id, user_id, session_id)", columns: [
                .init(key: .conversationId, constraints: "TEXT"),
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .sessionId, constraints: "TEXT"),
                .init(key: .sentToServer, constraints: "INTEGER"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: participantSession, into: db)
            
            let participants = TableDefinition<Participant>(constraints: "PRIMARY KEY(conversation_id, user_id)", columns: [
                .init(key: .conversationId, constraints: "TEXT"),
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .role, constraints: "TEXT"),
                .init(key: .status, constraints: "INTEGER"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: participants, into: db)
            
            let resendSessionMessage = TableDefinition<ResendSessionMessage>(constraints: "PRIMARY KEY(message_id, user_id, session_id)", columns: [
                .init(key: .messageId, constraints: "TEXT"),
                .init(key: .userId, constraints: "TEXT"),
                .init(key: .sessionId, constraints: "TEXT"),
                .init(key: .status, constraints: "INTEGER"),
            ])
            try self.migrateTable(with: participants, into: db)
            
            let snapshots = TableDefinition<Snapshot>(constraints: nil, columns: [
                .init(key: .snapshotId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .type, constraints: "TEXT"),
                .init(key: .assetId, constraints: "TEXT"),
                .init(key: .amount, constraints: "TEXT"),
                .init(key: .opponentId, constraints: "TEXT"),
                .init(key: .transactionHash, constraints: "TEXT"),
                .init(key: .sender, constraints: "TEXT"),
                .init(key: .receiver, constraints: "TEXT"),
                .init(key: .memo, constraints: "TEXT"),
                .init(key: .confirmations, constraints: "INTEGER"),
                .init(key: .traceId, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: snapshots, into: db)
            
            let stickerRelationships = TableDefinition<StickerRelationship>(constraints: "PRIMARY KEY(album_id, sticker_id)", columns: [
                .init(key: .albumId, constraints: "TEXT"),
                .init(key: .stickerId, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: stickerRelationships, into: db)
            
            let stickers = TableDefinition<Sticker>(constraints: nil, columns: [
                .init(key: .stickerId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .name, constraints: "TEXT"),
                .init(key: .assetUrl, constraints: "TEXT"),
                .init(key: .assetType, constraints: "TEXT"),
                .init(key: .assetWidth, constraints: "INTEGER"),
                .init(key: .assetHeight, constraints: "INTEGER"),
                .init(key: .lastUseAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: stickers, into: db)
            
            let topAssets = TableDefinition<TopAsset>(constraints: nil, columns: [
                .init(key: .assetId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .type, constraints: "TEXT"),
                .init(key: .symbol, constraints: "TEXT"),
                .init(key: .name, constraints: "TEXT"),
                .init(key: .iconUrl, constraints: "TEXT"),
                .init(key: .balance, constraints: "TEXT"),
                .init(key: .destination, constraints: "TEXT"),
                .init(key: .tag, constraints: "TEXT"),
                .init(key: .priceBtc, constraints: "TEXT"),
                .init(key: .priceUsd, constraints: "TEXT"),
                .init(key: .changeUsd, constraints: "TEXT"),
                .init(key: .chainId, constraints: "TEXT"),
                .init(key: .confirmations, constraints: "INTEGER"),
                .init(key: .assetKey, constraints: "TEXT"),
                .init(key: .reserve, constraints: "TEXT"),
            ])
            try self.migrateTable(with: topAssets, into: db)
            
            let traces = TableDefinition<Trace>(constraints: nil, columns: [
                .init(key: .traceId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .assetId, constraints: "TEXT"),
                .init(key: .amount, constraints: "TEXT"),
                .init(key: .opponentId, constraints: "TEXT"),
                .init(key: .destination, constraints: "TEXT"),
                .init(key: .tag, constraints: "TEXT"),
                .init(key: .snapshotId, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
            ])
            try self.migrateTable(with: topAssets, into: db)
            
            let users = TableDefinition<User>(constraints: nil, columns: [
                .init(key: .userId, constraints: "TEXT PRIMARY KEY"),
                .init(key: .fullName, constraints: "TEXT"),
                .init(key: .biography, constraints: "TEXT"),
                .init(key: .identityNumber, constraints: "TEXT"),
                .init(key: .avatarUrl, constraints: "TEXT"),
                .init(key: .phone, constraints: "TEXT"),
                .init(key: .isVerified, constraints: "INTEGER"),
                .init(key: .muteUntil, constraints: "TEXT"),
                .init(key: .appId, constraints: "TEXT"),
                .init(key: .relationship, constraints: "TEXT"),
                .init(key: .createdAt, constraints: "TEXT"),
                .init(key: .isScam, constraints: "INTEGER"),
            ])
            try self.migrateTable(with: users, into: db)
            
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
    
    private static func loadCurrent() -> UserDatabase {
        let db = try! UserDatabase(url: AppGroupContainer.mixinDatabaseUrl)
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
