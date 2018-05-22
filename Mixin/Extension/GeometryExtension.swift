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

extension CGSize {
    
    func rect(fittingSize containerSize: CGSize, byContentMode contentMode: UIViewContentMode) -> CGRect {
        switch contentMode {
        case .scaleAspectFit:
            let containerRatio = containerSize.width / containerSize.height
            let myRatio = width / height
            let size: CGSize, origin: CGPoint
            if myRatio > containerRatio {
                size = CGSize(width: containerSize.width, height: ceil(containerSize.width / myRatio))
                origin = CGPoint(x: 0, y: (containerSize.height - size.height) / 2)
            } else {
                size = CGSize(width: ceil(containerSize.height * myRatio), height: containerSize.height)
                origin = CGPoint(x: (containerSize.width - size.width) / 2, y: 0)
            }
            return CGRect(origin: origin, size: size)
        default:
            fatalError("Unimplemented")
        }
    }
    
}
