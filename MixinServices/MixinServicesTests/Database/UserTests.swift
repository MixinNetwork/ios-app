import XCTest
@testable import MixinServices

class UserTests: XCTestCase {
    
    let url = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("mixin.db", isDirectory: false)
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        print("Testing with URL: \(url)")
        let db = try SignalDatabase(url: url)
        SignalDatabase.reloadCurrent(with: db)
    }
    
    override func tearDownWithError() throws {
        UserDatabase.closeCurrent()
        try FileManager.default.removeItem(at: url)
    }
    
}
