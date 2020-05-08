import UIKit

enum BubblePath {
    
    static func path(from: BubbleLayer.Bubble, fromFrame: CGRect, to: BubbleLayer.Bubble, toFrame: CGRect) -> (from: CGPath?, to: CGPath?) {
        switch (from, to) {
        case (.left, .none):
            return (nil, BubblePath.noneFromLeft(frame: toFrame).cgPath)
        case (.leftWithTail, .none):
            return (nil, BubblePath.noneFromLeftWithTail(frame: toFrame).cgPath)
        case (.right, .none):
            return (nil, BubblePath.noneFromRight(frame: toFrame).cgPath)
        case (.rightWithTail, .none):
            return (nil, BubblePath.noneFromRightWithTail(frame: toFrame).cgPath)
        case (.none, .left):
            return (BubblePath.noneFromLeft(frame: fromFrame).cgPath,
                    BubblePath.left(frame: toFrame).cgPath)
        case (.none, .leftWithTail):
            return (BubblePath.noneFromLeftWithTail(frame: fromFrame).cgPath,
                    BubblePath.leftWithTail(frame: toFrame).cgPath)
        case (.none, .right):
            return (BubblePath.noneFromRight(frame: fromFrame).cgPath,
                    BubblePath.right(frame: toFrame).cgPath)
        case (.none, .rightWithTail):
            return (BubblePath.noneFromRightWithTail(frame: fromFrame).cgPath,
                    BubblePath.rightWithTail(frame: toFrame).cgPath)
        default:
            switch to {
            case .left:
                return (nil, BubblePath.left(frame: toFrame).cgPath)
            case .leftWithTail:
                return (nil, BubblePath.leftWithTail(frame: toFrame).cgPath)
            case .right:
                return (nil, BubblePath.right(frame: toFrame).cgPath)
            case .rightWithTail:
                return (nil, BubblePath.rightWithTail(frame: toFrame).cgPath)
            case .none:
                return (nil, CGPath(rect: toFrame, transform: nil))
            }
        }
    }
    
    static func left(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.minX + 9.01, y: frame.minY + 6))
        path.addCurve(to: CGPoint(x: frame.minX + 14.01, y: frame.minY + 1),
                      controlPoint1: CGPoint(x: frame.minX + 9.01, y: frame.minY + 3.24),
                      controlPoint2: CGPoint(x: frame.minX + 11.25, y: frame.minY + 1))
        path.addLine(to: CGPoint(x: frame.maxX - 7, y: frame.minY + 1))
        path.addCurve(to: CGPoint(x: frame.maxX - 2, y: frame.minY + 6),
                      controlPoint1: CGPoint(x: frame.maxX - 4.24, y: frame.minY + 1),
                      controlPoint2: CGPoint(x: frame.maxX - 2, y: frame.minY + 3.24))
        path.addLine(to: CGPoint(x: frame.maxX - 2, y: frame.maxY - 8))
        path.addCurve(to: CGPoint(x: frame.maxX - 7, y: frame.maxY - 3),
                      controlPoint1: CGPoint(x: frame.maxX - 2, y: frame.maxY - 5.24),
                      controlPoint2: CGPoint(x: frame.maxX - 4.24, y: frame.maxY - 3))
        path.addLine(to: CGPoint(x: frame.minX + 14.01, y: frame.maxY - 3))
        path.addCurve(to: CGPoint(x: frame.minX + 9.01, y: frame.maxY - 8),
                      controlPoint1: CGPoint(x: frame.minX + 11.25, y: frame.maxY - 3),
                      controlPoint2: CGPoint(x: frame.minX + 9.01, y: frame.maxY - 5.24))
        path.addCurve(to: CGPoint(x: frame.minX + 9.01, y: frame.minY + 6),
                      controlPoint1: CGPoint(x: frame.minX + 9, y: frame.maxY - 21.11),
                      controlPoint2: CGPoint(x: frame.minX + 9, y: frame.minY + 8.89))
        path.close()
        return path
    }
    
    static func leftWithTail(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.minX + 8.96, y: frame.maxY - 17.98))
        path.addCurve(to: CGPoint(x: frame.minX + 2.48, y: frame.maxY - 13.18),
                      controlPoint1: CGPoint(x: frame.minX + 7.33, y: frame.maxY - 15.71),
                      controlPoint2: CGPoint(x: frame.minX + 5.07, y: frame.maxY - 13.92))
        path.addCurve(to: CGPoint(x: frame.minX + 1.88, y: frame.maxY - 13.01),
                      controlPoint1: CGPoint(x: frame.minX + 2.21, y: frame.maxY - 13.1),
                      controlPoint2: CGPoint(x: frame.minX + 2.1, y: frame.maxY - 13.07))
        path.addCurve(to: CGPoint(x: frame.minX + 1.37, y: frame.maxY - 12.8),
                      controlPoint1: CGPoint(x: frame.minX + 1.66, y: frame.maxY - 12.95),
                      controlPoint2: CGPoint(x: frame.minX + 1.53, y: frame.maxY - 12.89))
        path.addCurve(to: CGPoint(x: frame.minX + 1, y: frame.maxY - 12),
                      controlPoint1: CGPoint(x: frame.minX + 1.1, y: frame.maxY - 12.63),
                      controlPoint2: CGPoint(x: frame.minX + 0.98, y: frame.maxY - 12.32))
        path.addCurve(to: CGPoint(x: frame.minX + 1.23, y: frame.maxY - 11.4),
                      controlPoint1: CGPoint(x: frame.minX + 1.03, y: frame.maxY - 11.79),
                      controlPoint2: CGPoint(x: frame.minX + 1.1, y: frame.maxY - 11.59))
        path.addCurve(to: CGPoint(x: frame.minX + 2.14, y: frame.maxY - 10.56),
                      controlPoint1: CGPoint(x: frame.minX + 1.41, y: frame.maxY - 11.12),
                      controlPoint2: CGPoint(x: frame.minX + 1.94, y: frame.maxY - 10.69))
        path.addCurve(to: CGPoint(x: frame.minX + 7.95, y: frame.maxY - 8.98),
                      controlPoint1: CGPoint(x: frame.minX + 3.83, y: frame.maxY - 9.47),
                      controlPoint2: CGPoint(x: frame.minX + 5.98, y: frame.maxY - 8.98))
        path.addCurve(to: CGPoint(x: frame.minX + 8.96, y: frame.maxY - 8.98),
                      controlPoint1: CGPoint(x: frame.minX + 8.3, y: frame.maxY - 8.98),
                      controlPoint2: CGPoint(x: frame.minX + 8.64, y: frame.maxY - 8.99))
        path.addCurve(to: CGPoint(x: frame.minX + 9, y: frame.maxY - 8),
                      controlPoint1: CGPoint(x: frame.minX + 8.97, y: frame.maxY - 8.61),
                      controlPoint2: CGPoint(x: frame.minX + 8.98, y: frame.maxY - 8.29))
        path.addCurve(to: CGPoint(x: frame.minX + 14, y: frame.maxY - 3),
                      controlPoint1: CGPoint(x: frame.minX + 9, y: frame.maxY - 5.24),
                      controlPoint2: CGPoint(x: frame.minX + 11.24, y: frame.maxY - 3))
        path.addLine(to: CGPoint(x: frame.maxX - 7, y: frame.maxY - 3))
        path.addCurve(to: CGPoint(x: frame.maxX - 2, y: frame.maxY - 8),
                      controlPoint1: CGPoint(x: frame.maxX - 4.23, y: frame.maxY - 3),
                      controlPoint2: CGPoint(x: frame.maxX - 2, y: frame.maxY - 5.24))
        path.addLine(to: CGPoint(x: frame.maxX - 2, y: frame.minY + 6))
        path.addCurve(to: CGPoint(x: frame.maxX - 7, y: frame.minY + 1),
                      controlPoint1: CGPoint(x: frame.maxX - 2, y: frame.minY + 3.24),
                      controlPoint2: CGPoint(x: frame.maxX - 4.23, y: frame.minY + 1))
        path.addLine(to: CGPoint(x: frame.minX + 14, y: frame.minY + 1))
        path.addCurve(to: CGPoint(x: frame.minX + 9, y: frame.minY + 6),
                      controlPoint1: CGPoint(x: frame.minX + 11.24, y: frame.minY + 1),
                      controlPoint2: CGPoint(x: frame.minX + 9, y: frame.minY + 3.24))
        path.addCurve(to: CGPoint(x: frame.minX + 8.96, y: frame.maxY - 17.98),
                      controlPoint1: CGPoint(x: frame.minX + 8.97, y: frame.minY + 15.19),
                      controlPoint2: CGPoint(x: frame.minX + 8.96, y: frame.maxY - 18.13))
        path.close()
        return path
    }
    
    static func right(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.minX + 2.01, y: frame.minY + 6))
        path.addCurve(to: CGPoint(x: frame.minX + 7.01, y: frame.minY + 1),
                      controlPoint1: CGPoint(x: frame.minX + 2.01, y: frame.minY + 3.24),
                      controlPoint2: CGPoint(x: frame.minX + 4.25, y: frame.minY + 1))
        path.addLine(to: CGPoint(x: frame.maxX - 14, y: frame.minY + 1))
        path.addCurve(to: CGPoint(x: frame.maxX - 9, y: frame.minY + 6),
                      controlPoint1: CGPoint(x: frame.maxX - 11.24, y: frame.minY + 1),
                      controlPoint2: CGPoint(x: frame.maxX - 9, y: frame.minY + 3.24))
        path.addLine(to: CGPoint(x: frame.maxX - 9, y: frame.maxY - 8))
        path.addCurve(to: CGPoint(x: frame.maxX - 14, y: frame.maxY - 3),
                      controlPoint1: CGPoint(x: frame.maxX - 9, y: frame.maxY - 5.24),
                      controlPoint2: CGPoint(x: frame.maxX - 11.24, y: frame.maxY - 3))
        path.addLine(to: CGPoint(x: frame.minX + 7.01, y: frame.maxY - 3))
        path.addCurve(to: CGPoint(x: frame.minX + 2.01, y: frame.maxY - 8),
                      controlPoint1: CGPoint(x: frame.minX + 4.25, y: frame.maxY - 3),
                      controlPoint2: CGPoint(x: frame.minX + 2.01, y: frame.maxY - 5.24))
        path.addCurve(to: CGPoint(x: frame.minX + 2.01, y: frame.minY + 6),
                      controlPoint1: CGPoint(x: frame.minX + 2, y: frame.maxY - 21.11),
                      controlPoint2: CGPoint(x: frame.minX + 2, y: frame.minY + 8.89))
        path.close()
        return path
    }
    
    static func rightWithTail(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.maxX - 8.96, y: frame.maxY - 17.98))
        path.addCurve(to: CGPoint(x: frame.maxX - 2.47, y: frame.maxY - 13.18),
                      controlPoint1: CGPoint(x: frame.maxX - 7.32, y: frame.maxY - 15.71),
                      controlPoint2: CGPoint(x: frame.maxX - 5.06, y: frame.maxY - 13.92))
        path.addCurve(to: CGPoint(x: frame.maxX - 1.88, y: frame.maxY - 13.01),
                      controlPoint1: CGPoint(x: frame.maxX - 2.21, y: frame.maxY - 13.1),
                      controlPoint2: CGPoint(x: frame.maxX - 2.1, y: frame.maxY - 13.07))
        path.addCurve(to: CGPoint(x: frame.maxX - 1.37, y: frame.maxY - 12.8),
                      controlPoint1: CGPoint(x: frame.maxX - 1.66, y: frame.maxY - 12.95),
                      controlPoint2: CGPoint(x: frame.maxX - 1.53, y: frame.maxY - 12.89))
        path.addCurve(to: CGPoint(x: frame.maxX - 1, y: frame.maxY - 12),
                      controlPoint1: CGPoint(x: frame.maxX - 1.1, y: frame.maxY - 12.63),
                      controlPoint2: CGPoint(x: frame.maxX - 0.97, y: frame.maxY - 12.32))
        path.addCurve(to: CGPoint(x: frame.maxX - 1.22, y: frame.maxY - 11.4),
                      controlPoint1: CGPoint(x: frame.maxX - 1.02, y: frame.maxY - 11.79),
                      controlPoint2: CGPoint(x: frame.maxX - 1.1, y: frame.maxY - 11.59))
        path.addCurve(to: CGPoint(x: frame.maxX - 2.14, y: frame.maxY - 10.56),
                      controlPoint1: CGPoint(x: frame.maxX - 1.41, y: frame.maxY - 11.12),
                      controlPoint2: CGPoint(x: frame.maxX - 1.94, y: frame.maxY - 10.69))
        path.addCurve(to: CGPoint(x: frame.maxX - 7.95, y: frame.maxY - 8.98),
                      controlPoint1: CGPoint(x: frame.maxX - 3.82, y: frame.maxY - 9.47),
                      controlPoint2: CGPoint(x: frame.maxX - 5.97, y: frame.maxY - 8.98))
        path.addCurve(to: CGPoint(x: frame.maxX - 8.96, y: frame.maxY - 8.98),
                      controlPoint1: CGPoint(x: frame.maxX - 8.3, y: frame.maxY - 8.98),
                      controlPoint2: CGPoint(x: frame.maxX - 8.64, y: frame.maxY - 8.99))
        path.addCurve(to: CGPoint(x: frame.maxX - 9, y: frame.maxY - 8),
                      controlPoint1: CGPoint(x: frame.maxX - 8.96, y: frame.maxY - 8.61),
                      controlPoint2: CGPoint(x: frame.maxX - 8.98, y: frame.maxY - 8.29))
        path.addCurve(to: CGPoint(x: frame.maxX - 14, y: frame.maxY - 3),
                      controlPoint1: CGPoint(x: frame.maxX - 9, y: frame.maxY - 5.24),
                      controlPoint2: CGPoint(x: frame.maxX - 11.24, y: frame.maxY - 3))
        path.addLine(to: CGPoint(x: frame.minX + 7, y: frame.maxY - 3))
        path.addCurve(to: CGPoint(x: frame.minX + 2, y: frame.maxY - 8),
                      controlPoint1: CGPoint(x: frame.minX + 4.24, y: frame.maxY - 3),
                      controlPoint2: CGPoint(x: frame.minX + 2, y: frame.maxY - 5.24))
        path.addLine(to: CGPoint(x: frame.minX + 2, y: frame.minY + 6))
        path.addCurve(to: CGPoint(x: frame.minX + 7, y: frame.minY + 1),
                      controlPoint1: CGPoint(x: frame.minX + 2, y: frame.minY + 3.24),
                      controlPoint2: CGPoint(x: frame.minX + 4.24, y: frame.minY + 1))
        path.addLine(to: CGPoint(x: frame.maxX - 14, y: frame.minY + 1))
        path.addCurve(to: CGPoint(x: frame.maxX - 9, y: frame.minY + 6),
                      controlPoint1: CGPoint(x: frame.maxX - 11.24, y: frame.minY + 1),
                      controlPoint2: CGPoint(x: frame.maxX - 9, y: frame.minY + 3.24))
        path.addCurve(to: CGPoint(x: frame.maxX - 8.96, y: frame.maxY - 17.98),
                      controlPoint1: CGPoint(x: frame.maxX - 8.97, y: frame.minY + 15.19),
                      controlPoint2: CGPoint(x: frame.maxX - 8.96, y: frame.maxY - 18.13))
        path.close()
        return path
    }
    
    static func noneFromLeft(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.close()
        return path
    }
    
    static func noneFromLeftWithTail(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.minX, y: frame.maxY - 17.98))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 13.18))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 13.01))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 12.8))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 12))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 11.4))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 10.56))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 8.98))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 8.98))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 17.98))
        path.close()
        return path
    }
    
    static func noneFromRight(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.close()
        return path
    }
    
    static func noneFromRightWithTail(frame: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: frame.maxX, y: frame.maxY - 17.98))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 13.18))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 13.01))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 12.8))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 12))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 11.4))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 10.56))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 8.98))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 8.98))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 8))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 8))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY + 6))
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + 6))
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 17.98))
        path.close()
        return path
    }
    
}
