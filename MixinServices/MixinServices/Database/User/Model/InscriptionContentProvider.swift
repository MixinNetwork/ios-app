import Foundation
import UniformTypeIdentifiers

public enum InscriptionContent {
    case image(URL)
    case text(icon: URL, text: URL)
}

public protocol InscriptionContentProvider {
    var inscriptionCollectionIconURL: String? { get }
    var inscriptionContentType: String? { get }
    var inscriptionContentURL: String? { get }
}

public extension InscriptionContentProvider {
    
    public var inscriptionContent: InscriptionContent? {
        guard
            let type = inscriptionContentType,
            let urlString = inscriptionContentURL,
            let contentURL = URL(string: urlString)
        else {
            return nil
        }
        if type.starts(with: "image/") {
            let svg = UTType.svg.preferredMIMEType ?? "image/svg+xml"
            if type == svg {
                return nil
            } else {
                return .image(contentURL)
            }
        } else if type.starts(with: "text/") {
            if let collectionIconURLString = inscriptionCollectionIconURL,
               let iconURL = URL(string: collectionIconURLString)
            {
                return .text(icon: iconURL, text: contentURL)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
}
