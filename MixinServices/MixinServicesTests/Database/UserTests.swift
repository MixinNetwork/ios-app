import XCTest
@testable import MixinServices

class UserTests: XCTestCase {
    
    override class func setUp() {
        print("Testing with URL: \(AppGroupContainer.userDatabaseUrl)")
        let fileExists = FileManager.default.fileExists(atPath: AppGroupContainer.userDatabaseUrl.path)
        if fileExists {
            assertionFailure("The test corrupts your existed app data. Test it with a fresh device.")
        }
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        UserDatabase.reloadCurrent()
    }
    
    override func tearDownWithError() throws {
        UserDatabase.closeCurrent()
        let filenames = try FileManager.default.contentsOfDirectory(atPath: AppGroupContainer.documentsUrl.path)
        for filename in filenames {
            let url = AppGroupContainer.documentsUrl.appendingPathComponent(filename)
            try FileManager.default.removeItem(at: url)
        }
    }
    
    func testTableMigration() {
        var migrations = UserDatabase.current.tableMigrations
        let sqls = [
            "CREATE TABLE addresses(type TEXT, address_id TEXT PRIMARY KEY, asset_id TEXT, destination TEXT, label TEXT, tag TEXT, fee TEXT, reserve TEXT, dust TEXT, updated_at TEXT)",
            "CREATE TABLE albums(album_id TEXT PRIMARY KEY, name TEXT, icon_url TEXT, created_at TEXT, update_at TEXT, user_id TEXT, category TEXT, description TEXT)",
            "CREATE TABLE apps(app_id TEXT PRIMARY KEY, app_number TEXT, redirect_uri TEXT, name TEXT, category TEXT, icon_url TEXT, capabilites BLOB, resource_patterns BLOB, home_uri TEXT, creator_id TEXT, updated_at TEXT)",
            "CREATE TABLE assets(asset_id TEXT PRIMARY KEY, type TEXT, symbol TEXT, name TEXT, icon_url TEXT, balance TEXT, destination TEXT, tag TEXT, price_btc TEXT, price_usd TEXT, change_usd TEXT, chain_id TEXT, confirmations INTEGER, asset_key TEXT, reserve TEXT)",
            "CREATE TABLE circle_conversations(circle_id TEXT, conversation_id TEXT, user_id TEXT, created_at TEXT, pin_time TEXT, PRIMARY KEY(conversation_id, circle_id))",
            "CREATE TABLE circles(circle_id TEXT PRIMARY KEY, name TEXT, created_at TEXT)",
            "CREATE TABLE conversations(conversation_id TEXT PRIMARY KEY, owner_id TEXT, category TEXT, name TEXT, icon_url TEXT, announcement TEXT, last_message_id TEXT, last_message_created_at TEXT, last_read_message_id TEXT, unseen_message_count INTEGER, status INTEGER, draft TEXT, mute_until TEXT, code_url TEXT, pin_time TEXT)",
            "CREATE TABLE favorite_apps(user_id TEXT, app_id TEXT, created_at TEXT, PRIMARY KEY(user_id, app_id))",
            "CREATE TABLE jobs(orderId INTEGER PRIMARY KEY AUTOINCREMENT, job_id TEXT, priority INTEGER, blaze_message BLOB, blaze_message_data BLOB, action TEXT, category TEXT, conversation_id TEXT, user_id TEXT, resend_message_id TEXT, message_id TEXT, status TEXT, session_id TEXT)",
            "CREATE TABLE message_mentions(message_id TEXT PRIMARY KEY, conversation_id TEXT, mentions BLOB, has_read INTEGER)",
            "CREATE TABLE messages(id TEXT PRIMARY KEY, conversation_id TEXT, user_id TEXT, category TEXT, content TEXT, media_url TEXT, media_mime_type TEXT, media_size INTEGER, media_duration INTEGER, media_width INTEGER, media_height INTEGER, media_hash TEXT, media_key BLOB, media_digest BLOB, media_status TEXT, media_waveform BLOB, media_local_id TEXT, thumb_image TEXT, thumb_url TEXT, status TEXT, action TEXT, participant_id TEXT, snapshot_id TEXT, name TEXT, sticker_id TEXT, shared_user_id TEXT, quote_message_id TEXT, quote_content BLOB, created_at TEXT)",
            "CREATE TABLE messages_history(message_id TEXT PRIMARY KEY)",
            "CREATE TABLE participant_session(conversation_id TEXT, user_id TEXT, session_id TEXT, sent_to_server INTEGER, created_at TEXT, PRIMARY KEY(conversation_id, user_id, session_id))",
            "CREATE TABLE participants(conversation_id TEXT, user_id TEXT, role TEXT, status INTEGER, created_at TEXT, PRIMARY KEY(conversation_id, user_id))",
            "CREATE TABLE resend_session_messages(message_id TEXT, user_id TEXT, session_id TEXT, status INTEGER, PRIMARY KEY(message_id, user_id, session_id))",
            "CREATE TABLE snapshots(snapshot_id TEXT PRIMARY KEY, type TEXT, asset_id TEXT, amount TEXT, opponent_id TEXT, transaction_hash TEXT, sender TEXT, receiver TEXT, memo TEXT, confirmations INTEGER, trace_id TEXT, created_at TEXT)",
            "CREATE TABLE sticker_relationships(album_id TEXT, sticker_id TEXT, created_at TEXT, PRIMARY KEY(album_id, sticker_id))",
            "CREATE TABLE stickers(sticker_id TEXT PRIMARY KEY, name TEXT, asset_url TEXT, asset_type TEXT, asset_width INTEGER, asset_height INTEGER, last_used_at TEXT)",
            "CREATE TABLE top_assets(asset_id TEXT PRIMARY KEY, type TEXT, symbol TEXT, name TEXT, icon_url TEXT, balance TEXT, destination TEXT, tag TEXT, price_btc TEXT, price_usd TEXT, change_usd TEXT, chain_id TEXT, confirmations INTEGER, asset_key TEXT, reserve TEXT)",
            "CREATE TABLE traces(trace_id TEXT PRIMARY KEY, asset_id TEXT, amount TEXT, opponent_id TEXT, destination TEXT, tag TEXT, snapshot_id TEXT, created_at TEXT)",
            "CREATE TABLE users(user_id TEXT PRIMARY KEY, full_name TEXT, biography TEXT, identity_number TEXT, avatar_url TEXT, phone TEXT, is_verified INTEGER, mute_until TEXT, app_id TEXT, relationship TEXT, created_at TEXT, is_scam INTEGER)",
        ]
        XCTAssertEqual(migrations.count, sqls.count)
        while !migrations.isEmpty {
            guard let migration = migrations.last else {
                break
            }
            let migrationSQL = migration.createTableSQL()
            guard let originalSQL = sqls.first(where: { $0.hasPrefix("CREATE TABLE \(migration.tableName)") }) else {
                XCTAssert(false)
                return
            }
            if migrationSQL != originalSQL {
                print("[NonEqual] m: \(migrationSQL)")
                print("[NonEqual] o: \(originalSQL)")
            }
            XCTAssertEqual(migrationSQL, originalSQL)
            migrations.removeLast()
        }
    }
    
}
