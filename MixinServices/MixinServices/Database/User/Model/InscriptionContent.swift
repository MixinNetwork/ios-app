import Foundation

public protocol InscriptionContent {
    var contentType: String { get }
    var contentURL: String { get }
}

public extension InscriptionContent {
    
    public var imageContentURL: URL? {
        guard contentType.starts(with: "image/") else {
            return nil
        }
        return URL(string: contentURL)
    }
    
}
