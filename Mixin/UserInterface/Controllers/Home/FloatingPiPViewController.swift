import UIKit

class FloatingPiPViewController: UIViewController {
    
    @IBOutlet weak var contentView: UIView!
    
    @IBOutlet var panRecognizer: UIPanGestureRecognizer!
    
    private let contentMargin: CGFloat = 20
    
    private var centerRestriction: CGRect {
        let superview = parent?.view ?? AppDelegate.current.mainWindow
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.shadowPath = CGPath(roundedRect: contentView.frame.offsetBy(dx: 0, dy: 4),
                                       cornerWidth: contentView.layer.cornerRadius,
                                       cornerHeight: contentView.layer.cornerRadius,
                                       transform: nil)
    }
    
    @IBAction func panAction(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            recognizer.setTranslation(.zero, in: nil)
        case .changed:
            view.center = view.center + recognizer.translation(in: nil)
            recognizer.setTranslation(.zero, in: nil)
        case .ended:
            updateViewSize()
            stickViewToEdge(center: view.center, animated: true)
        default:
            break
        }
    }
    
    func updateViewSize() {
        view.layoutIfNeeded()
        view.bounds.size = CGSize(width: contentView.frame.width + contentMargin,
                                  height: contentView.frame.height + contentMargin)
    }
    
    func placeViewToTopRight() {
        updateViewSize()
        view.center = CGPoint(x: centerRestriction.maxX,
                              y: centerRestriction.minY)
    }
    
    func stickViewToEdge(center: CGPoint, animated: Bool) {
        let newCenter: CGPoint = {
            let x = center.x > centerRestriction.midX ? centerRestriction.maxX : centerRestriction.minX
            let y = max(centerRestriction.minY, min(centerRestriction.maxY, center.y))
            return CGPoint(x: x, y: y)
        }()
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.view.center = newCenter
        }, completion: nil)
    }
    
    func stickViewToEdgeIfNotPanning(center: CGPoint, animated: Bool) {
        guard ![.began, .changed, .ended].contains(panRecognizer.state) else {
            return
        }
        stickViewToEdge(center: center, animated: animated)
    }
    
}
