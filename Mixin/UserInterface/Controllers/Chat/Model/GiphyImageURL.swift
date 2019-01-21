import Foundation
import GiphyCoreSDK

class GiphyImageURL {
    
    let preview: URL
    let fullsized: URL
    
    init?(media: GPHMedia) {
        guard let previewString = media.images?.fixedWidthDownsampled?.gifUrl, let previewURL = URL(string: previewString), let fullsizedString = media.images?.fixedWidth?.gifUrl, let fullsizedURL = URL(string: fullsizedString) else {
            return nil
        }
        self.preview = previewURL
        self.fullsized = fullsizedURL
    }
    
}
