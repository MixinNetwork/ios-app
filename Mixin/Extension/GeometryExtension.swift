import UIKit

func ceil(_ size: CGSize) -> CGSize {
    return CGSize(width: ceil(size.width), height: ceil(size.height))
}

extension CGPoint {
    
    static prefix func -(point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }
    
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
}

extension UIEdgeInsets {
    
    var horizontal: CGFloat {
        return left + right
    }
    
    var vertical: CGFloat {
        return top + bottom
    }
    
}
