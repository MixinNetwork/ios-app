import Foundation
import WCDBSwift

public struct FiatMoney: Codable {
    
    public let code: String
    
    // Decoding decimal numbers directly from ASCII string is supported by JSONDecoder since Swift 5.0
    // See https://github.com/apple/swift-corelibs-foundation/pull/1657/files
    public let rate: Decimal
    
}
