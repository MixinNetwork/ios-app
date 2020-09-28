import UIKit

class Link {
    
    struct Range {
        let range: NSRange
        let url: URL
    }
    
    static let detector = FastURLDetector()
    
    let hitFrame: CGRect
    let backgroundPath: UIBezierPath
    let url: URL
    
    init(hitFrame: CGRect, backgroundPath: UIBezierPath, url: URL) {
        self.hitFrame = hitFrame
        self.backgroundPath = backgroundPath
        self.url = url
    }
    
}
