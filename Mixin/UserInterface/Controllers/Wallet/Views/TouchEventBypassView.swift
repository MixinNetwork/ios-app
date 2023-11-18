import UIKit

final class TouchEventBypassView: UIView {
    
    weak var exception: UIView?
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if let exception, exception.isDescendant(of: self) {
            let point = exception.convert(point, from: self)
            return exception.point(inside: point, with: event)
        } else {
            return false
        }
    }
    
}
