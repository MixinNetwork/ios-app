import Foundation

public enum InscriptionContent {
    case image(URL)
    case text(URL)
}

public protocol InscriptionContentProvider {
    var inscriptionContentType: String? { get }
    var inscriptionContentURL: String? { get }
}

public extension InscriptionContentProvider {
    
    public var inscriptionContent: InscriptionContent? {
        guard
            let type = inscriptionContentType,
            let urlString = inscriptionContentURL,
            let url = URL(string: urlString)
        else {
            return nil
        }
        if type.starts(with: "image/") {
            return .image(url)
        } else if type.starts(with: "text/") {
            return .text(url)
        } else {
            return nil
        }
    }
    
}
