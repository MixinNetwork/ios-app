import Foundation

public protocol InscriptionContent {
    var inscriptionContentType: String? { get }
    var inscriptionContentURL: String? { get }
}

public extension InscriptionContent {
    
    public var inscriptionImageContentURL: URL? {
        guard
            let type = inscriptionContentType,
            type.starts(with: "image/"),
            let string = inscriptionContentURL
        else {
            return nil
        }
        return URL(string: string)
    }
    
}
