import Foundation

protocol AssetKeyConvertible {
    var publicKey: String? { get }
    var accountName: String? { get }
    var accountTag: String? { get }
}

extension AssetKeyConvertible {
    
    var isAccount: Bool {
        return !(accountName?.isEmpty ?? true || accountTag?.isEmpty ?? true)
    }
    
    var isAddress: Bool {
        return !(publicKey?.isEmpty ?? true)
    }
    
}
