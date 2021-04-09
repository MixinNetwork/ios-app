import UIKit

func ceil(_ size: CGSize) -> CGSize {
    return CGSize(width: ceil(size.width), height: ceil(size.height))
}

func round(_ size: CGSize) -> CGSize {
    return CGSize(width: round(size.width), height: round(size.height))
}

func round(_ point: CGPoint) -> CGPoint {
    return CGPoint(x: round(point.x), y: round(point.y))
}

func floor(_ point: CGPoint) -> CGPoint {
    return CGPoint(x: floor(point.x), y: floor(point.y))
}

extension CGPoint {
    
    static prefix func -(point: CGPoint) -> CGPoint {
        return CGPoint(x: -point.x, y: -point.y)
    }
    
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
    
    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
    
    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
    
    static func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        return CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
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

extension CGAffineTransform {
    
    static let italic = CGAffineTransform(a: 1, b: 0, c: tan(.pi / 14), d: 1, tx: 0, ty: 0).translatedBy(x: 0, y: -1)
    
}
