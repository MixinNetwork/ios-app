import UIKit

class ChevronView: UIView {
    
    static let chevronPieceFrame = CGRect(x: 0, y: 0, width: 21, height: 4.5)
    
    let leftView = ChevronView.newChevronPiece()
    let rightView = ChevronView.newChevronPiece()
    
    private var animator: UIViewPropertyAnimator?
    
    var isDiagonal = false {
        didSet {
            updateViews(diagonal: isDiagonal)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let halfCanvasWidth = frame.width / 2
        let distance = sqrt(3) / 4 * ChevronView.chevronPieceFrame.width - 0.5
        let y = frame.height / 2
        leftView.center = CGPoint(x: halfCanvasWidth - distance, y: y)
        rightView.center = CGPoint(x: halfCanvasWidth + distance, y: y)
    }
    
    private func prepare() {
        addSubview(leftView)
        addSubview(rightView)
        isDiagonal = true
    }
    
    private func updateViews(diagonal: Bool) {
        animator?.stopAnimation(true)
        animator?.finishAnimation(at: .current)
        animator = UIViewPropertyAnimator(duration: 0.2, curve: .linear, animations: {
            let angle = CGFloat.pi / 8
            if diagonal {
                self.leftView.transform = CGAffineTransform(rotationAngle: angle)
                self.rightView.transform = CGAffineTransform(rotationAngle: -angle)
            } else {
                self.leftView.transform = .identity
                self.rightView.transform = .identity
            }
        })
        animator?.startAnimation()
    }
    
    private static func newChevronPiece() -> UIView {
        let view = UIView(frame: chevronPieceFrame)
        view.backgroundColor = UIColor(rgbValue: 0xDADEE5)
        view.clipsToBounds = true
        let layer = view.layer
        layer.cornerRadius = chevronPieceFrame.height / 2
        layer.allowsEdgeAntialiasing = false
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
        return view
    }
    
}
