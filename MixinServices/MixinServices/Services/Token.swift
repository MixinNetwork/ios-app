import Foundation

public protocol Token {
    
    var assetID: String { get }
    var name: String { get }
    var symbol: String { get }
    var iconURL: String { get }
    
}
