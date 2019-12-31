import Foundation

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
        
        init?(width: String, height: String) {
            guard let width = Int(width), let height = Int(height) else {
                return nil
            }
            self.init(width: width, height: height)
        }
        
    }
    
    let previewUrl: URL
    let fullsizedUrl: URL
    let size: Size
    
    init?(json: [String: Any]) {
        guard let images = json["images"] as? [String: Any] else {
            return nil
        }
        guard let preview = images["fixed_width_downsampled"] as? [String: Any] else {
            return nil
        }
        guard let previewUrlString = preview["url"] as? String else {
            return nil
        }
        guard let previewUrl = URL(string: previewUrlString) else {
            return nil
        }
        guard let fullsized = images["fixed_width"] as? [String: Any] else {
            return nil
        }
        guard let str = fullsized["url"] as? String, let fullsizedUrl = URL(string: str) else {
            return nil
        }
        guard let width = fullsized["width"] as? String, let height = fullsized["height"] as? String else {
            return nil
        }
        guard let size = Size(width: width, height: height) else {
            return nil
        }
        self.previewUrl = previewUrl
        self.fullsizedUrl = fullsizedUrl
        self.size = size
    }
    
}
