import Foundation
import GiphyCoreSDK

extension GPHMedia {
    
    var mixinImageURL: URL? {
        guard let str = images?.fixedWidth?.gifUrl else {
            return nil
        }
        return URL(string: str)
    }
    
}
