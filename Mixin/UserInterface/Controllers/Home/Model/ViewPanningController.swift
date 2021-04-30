import UIKit

protocol ViewPanningControllerDelegate: AnyObject {
    func animateAlongsideViewPanningControllerEdgeSticking(_ controller: ViewPanningController)
}

class ViewPanningController {
    
    var isEnabled: Bool {
        get {
            panRecognizer.isEnabled
        }
        set {
            panRecognizer.isEnabled = newValue
        }
    }
    
    weak var delegate: ViewPanningControllerDelegate?
    
    private let view: UIView
    private let stickToEdgeVelocityLimit: CGFloat = 800
    
    private(set) var stickingEdge: UIRectEdge = .right
    
    private var panRecognizer: UIPanGestureRecognizer!
    
    private weak var overlaysCoordinator = UIApplication.homeContainerViewController?.overlaysCoordinator
    
    private var centerRestriction: CGRect {
        let superview = view.superview ?? AppDelegate.current.mainWindow
        let halfContentWidth = view.frame.size.width / 2
        let halfContentHeight = view.frame.size.height / 2
        let contentInsets = UIEdgeInsets(top: halfContentHeight,
                                         left: halfContentWidth,
                                         bottom: halfContentHeight,
                                         right: halfContentWidth)
        return superview.bounds
            .inset(by: superview.safeAreaInsets)
            .inset(by: contentInsets)
    }
    
    init(view: UIView) {
        self.view = view
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(panAction(_:)))
        view.addGestureRecognizer(recognizer)
        self.panRecognizer = recognizer
    }
    
    @objc func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: nil)
            view.superview?.bringSubviewToFront(view)
        case .changed:
            let center = view.center + recognizer.translation(in: nil)
            view.center = center
            recognizer.setTranslation(.zero, in: nil)
        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: nil).x
            stickViewToParentEdge(horizontalVelocity: velocity, animated: true)
        default:
            break
        }
    }
    
    func placeViewNextToLastOverlayOrTopRight() {
        let y: CGFloat
        if let previous = overlaysCoordinator?.bottomRightOverlay, previous != self.view {
            y = previous.frame.maxY + view.frame.height / 2
        } else {
            // Overlay looks better if the navigation bar is not covered
            y = centerRestriction.minY + 44
        }
        let center = CGPoint(x: centerRestriction.maxX, y: y)
        overlaysCoordinator?.update(center: center, for: view)
    }
    
    func stickViewToParentEdge(horizontalVelocity: CGFloat, animated: Bool) {
        let shouldStickToRightEdge = (view.center.x > centerRestriction.midX && horizontalVelocity > -stickToEdgeVelocityLimit)
            || (view.center.x < centerRestriction.midX && horizontalVelocity > stickToEdgeVelocityLimit)
        stickingEdge = shouldStickToRightEdge ? .right : .left
        let x = shouldStickToRightEdge ? centerRestriction.maxX : centerRestriction.minX
        let center = CGPoint(x: x, y: view.center.y) // y will be clamped by overlays coordinator
        let layout: () -> Void = {
            self.delegate?.animateAlongsideViewPanningControllerEdgeSticking(self)
            self.overlaysCoordinator?.update(center: center, for: self.view)
        }
        if animated {
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           options: .curveEaseOut,
                           animations: layout,
                           completion: nil)
        } else {
            layout()
        }
    }
    
    func stickViewToEdgeIfNotPanning(animated: Bool) {
        guard ![.began, .changed, .ended].contains(panRecognizer.state) else {
            return
        }
        stickViewToParentEdge(horizontalVelocity: 0, animated: animated)
    }
    
}
