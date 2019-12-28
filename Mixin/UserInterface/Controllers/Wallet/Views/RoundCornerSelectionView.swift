import UIKit

class RoundCornerSelectionView: UIView {
    
    private let contentLayer = CAShapeLayer()
    private let cornerRadii = CGSize(width: 8, height: 8)
        
    var roundingCorners: UIRectCorner = [] {
        didSet {
            updateContentPath()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateContentPath()
    }
    
    func setHighlighted(_ highlighted: Bool, animated: Bool) {
        let color: UIColor = highlighted ? .selectionBackground : .white
        let work = {
            self.contentLayer.fillColor = color.cgColor
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work)
        } else {
            work()
        }
    }
    
    private func prepare() {
        updateContentPath()
        contentLayer.fillColor = UIColor.white.cgColor
        layer.insertSublayer(contentLayer, at: 0)
    }
    
    private func updateContentPath() {
        let path = UIBezierPath(roundedRect: bounds,
                                byRoundingCorners: roundingCorners,
                                cornerRadii: cornerRadii)
        contentLayer.path = path.cgPath
    }
    
}
