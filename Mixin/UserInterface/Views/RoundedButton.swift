import UIKit

class RoundedButton: UIButton {
    
    override var isEnabled: Bool {
        didSet {
            let color = isEnabled ? UIColor.theme : UIColor(rgbValue: 0xE5E7EC)
            backgroundLayer.fillColor = color.cgColor
        }
    }
    
    var isBusy = false {
        didSet {
            if isBusy {
                backgroundLayer.removeFromSuperlayer()
                if !activityIndicator.isDescendant(of: self) {
                    addSubview(activityIndicator)
                    activityIndicator.snp.makeConstraints { (make) in
                        make.center.equalToSuperview()
                    }
                }
                activityIndicator.startAnimating()
                layer.insertSublayer(backgroundLayer, below: activityIndicator.layer)
            } else {
                backgroundLayer.removeFromSuperlayer()
                activityIndicator.stopAnimating()
                layer.insertSublayer(backgroundLayer, at: 0)
            }
        }
    }

    @IBInspectable var cornerRadius: CGFloat = 20
    
    private let backgroundLayer = CAShapeLayer()
    private lazy var activityIndicator = UIActivityIndicatorView(style: .white)
    
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
        updatePaths()
    }
    
    private func prepare() {
        setTitleColor(.white, for: .normal)
        updatePaths()
        backgroundLayer.fillColor = (isEnabled ? UIColor.theme : UIColor(rgbValue: 0xE5E7EC)).cgColor
        backgroundLayer.shadowColor = UIColor.theme.cgColor
        backgroundLayer.shadowOpacity = 0.15
        backgroundLayer.shadowRadius = 5
        layer.insertSublayer(backgroundLayer, at: 0)
    }
    
    private func updatePaths() {
        let cornerRadius = bounds.height / 2
        backgroundLayer.path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let rect = CGRect(x: 0, y: 6, width: bounds.width, height: bounds.height)
        backgroundLayer.shadowPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    }
    
}
