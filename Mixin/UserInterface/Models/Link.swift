import UIKit

class Link {
    
    static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    
    let hitFrame: CGRect
    let backgroundPath: UIBezierPath
    let url: URL
    
    init(hitFrame: CGRect, backgroundPath: UIBezierPath, url: URL) {
        self.hitFrame = hitFrame
        self.backgroundPath = backgroundPath
        self.url = url
    }
    
}
