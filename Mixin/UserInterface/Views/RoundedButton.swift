import UIKit

class RoundedButton: UIButton {
    
    override var isEnabled: Bool {
        didSet {
            updateAppearanceWithIsEnabled()
        }
    }
    
    var isBusy = false {
        didSet {
            if isBusy {
                backgroundLayer.removeFromSuperlayer()
                addActivityIndicatorIfNeeded()
                activityIndicator.startAnimating()
                layer.insertSublayer(backgroundLayer, below: activityIndicator.layer)
            } else {
                backgroundLayer.removeFromSuperlayer()
                activityIndicator.stopAnimating()
                layer.insertSublayer(backgroundLayer, above: shadowLayer)
            }
        }
    }

    @IBInspectable var cornerRadius: CGFloat = 20
    
    private let backgroundLayer = CAShapeLayer()
    private let shadowLayer = CALayer()
    private let backgroundEnableColor = UIColor.theme
    private let backgroundDisableColor = R.color.button_background_disabled()!
    private let textDisableColor = R.color.button_text_disabled()!
    
    private lazy var activityIndicator = ActivityIndicatorView()
    
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
        backgroundLayer.frame = bounds
        shadowLayer.frame = bounds
        updatePaths()
    }
    
    private func prepare() {
        setTitleColor(.white, for: .normal)
        setTitleColor(textDisableColor, for: .disabled)
        updatePaths()
        updateAppearanceWithIsEnabled()
        shadowLayer.shadowColor = UIColor.theme.cgColor
        shadowLayer.shadowOpacity = 0.15
        shadowLayer.shadowRadius = 5
        layer.insertSublayer(shadowLayer, at: 0)
        layer.insertSublayer(backgroundLayer, above: shadowLayer)
    }
    
    private func updatePaths() {
        let cornerRadius = bounds.height / 2
        backgroundLayer.path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        let rect = CGRect(x: 0, y: 6, width: bounds.width, height: bounds.height)
        shadowLayer.shadowPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    }
    
    private func updateAppearanceWithIsEnabled() {
        let color: UIColor = isEnabled ? backgroundEnableColor : backgroundDisableColor
        backgroundLayer.fillColor = color.cgColor
        shadowLayer.isHidden = !isEnabled
    }
    
    private func addActivityIndicatorIfNeeded() {
        guard !activityIndicator.isDescendant(of: self) else {
            return
        }
        activityIndicator.tintColor = .white
        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
        }
    }
    
}
