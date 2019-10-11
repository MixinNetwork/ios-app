import Foundation

protocol AssetKeyConvertible {
    var destination: String { get }
    var tag: String { get }
}

extension AssetKeyConvertible {
    
    var isAccount: Bool {
        return !destination.isEmpty && !tag.isEmpty
    }

    var isAddress: Bool {
        return !destination.isEmpty && tag.isEmpty
    }
}
