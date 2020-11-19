import Foundation

extension CGSize {

    public static func +(lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }

    public static func -(lhs: CGSize, rhs: CGSize) -> CGSize {
        return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
    }

    public static func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    public static func /(lhs: CGSize, rhs: CGFloat) -> CGSize {
        return CGSize(width: lhs.width / rhs, height: lhs.height / rhs)
    }

    public func rect(fittingSize containerSize: CGSize) -> CGRect {
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
    }
    
    public func sizeThatFits(_ canvasSize: CGSize) -> CGSize {
        let containerRatio = canvasSize.width / canvasSize.height
        let myRatio = width / height
        let size: CGSize
        if myRatio > containerRatio {
            size = CGSize(width: canvasSize.width, height: round(canvasSize.width / myRatio))
        } else {
            size = CGSize(width: round(canvasSize.height * myRatio), height: canvasSize.height)
        }
        return size
    }
    
}
