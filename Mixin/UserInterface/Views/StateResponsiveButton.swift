import UIKit

class StateResponsiveButton: CornerButton {
    
    let activityIndicator = ActivityIndicatorView()
    
    @IBInspectable var enabledColor: UIColor?
    @IBInspectable var disabledColor: UIColor?
    
    private var normalTitleColor: UIColor?
    private var normalImage: UIImage?
    
    override var isEnabled: Bool {
        didSet {
            updateWithIsEnabled()
        }
    }
    
    var isBusy: Bool = false {
        didSet {
            updateWithIsBusy()
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

    func updateWithIsEnabled() {
        backgroundColor = isEnabled ? enabledColor : disabledColor
    }
    
    func updateWithIsBusy() {
        if isBusy {
            setTitleColor(.clear, for: .normal)
            setImage(nil, for: .normal)
            isUserInteractionEnabled = false
            activityIndicator.startAnimating()
        } else {
            setTitleColor(normalTitleColor, for: .normal)
            setImage(normalImage, for: .normal)
            isUserInteractionEnabled = true
            activityIndicator.stopAnimating()
        }
    }
    
    private func prepare() {
        enabledColor = .theme
        disabledColor = R.color.button_background_disabled()
        activityIndicator.tintColor = .accessoryText
        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { (make) in
            make.centerX.equalTo(snp.centerX)
            make.centerY.equalTo(snp.centerY)
        }
        activityIndicator.hidesWhenStopped = true
        activityIndicator.stopAnimating()
        saveNormalState()
    }

    func saveNormalState() {
        normalTitleColor = titleColor(for: .normal)
        normalImage = image(for: .normal)
    }
    
}
