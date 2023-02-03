import UIKit

public class Link {
    
    public struct Range {
        public let range: NSRange
        public let url: URL
        
        public init(range: NSRange, url: URL) {
            self.range = range
            self.url = url
        }
    }
    
    public static let detector = FastURLDetector()
    
    public let hitFrame: CGRect
    public let backgroundPath: UIBezierPath
    public let url: URL
    
    public init(hitFrame: CGRect, backgroundPath: UIBezierPath, url: URL) {
        self.hitFrame = hitFrame
        self.backgroundPath = backgroundPath
        self.url = url
    }
    
}
