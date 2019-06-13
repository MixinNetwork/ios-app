import Foundation
import GiphyCoreSDK

class GiphyImage {
    
    struct Size {
        
        let width: Int
        let height: Int
        
        init?(width: Int, height: Int) {
            guard width > 0 && height > 0 else {
                return nil
            }
            self.width = width
            self.height = height
        }
        
    }
    
    let previewUrl: URL
    let fullsizedUrl: URL
    let size: Size
    
    init?(media: GPHMedia) {
        guard let images = media.images else {
            return nil
        }
        guard let previewUrlString = images.fixedWidthDownsampled?.gifUrl else {
            return nil
        }
        guard let previewUrl = URL(string: previewUrlString) else {
            return nil
        }
        guard let fullsized = images.fixedWidth else {
            return nil
        }
        guard let str = fullsized.gifUrl, let fullsizedUrl = URL(string: str) else {
            return nil
        }
        guard let size = Size(width: fullsized.width, height: fullsized.height) else {
            return nil
        }
        self.previewUrl = previewUrl
        self.fullsizedUrl = fullsizedUrl
        self.size = size
    }
    
}
