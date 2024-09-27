import UIKit

class BusyButton: UIButton {
    
    let busyIndicator = ActivityIndicatorView()

    private var normalTitleColor: UIColor?
    private var normalImage: UIImage?
    
    var isBusy = false {
        didSet {
            if isBusy {
                isUserInteractionEnabled = false
                normalTitleColor = titleColor(for: .normal)
                normalImage = image(for: .normal)
                setTitleColor(.clear, for: .normal)
                setImage(nil, for: .normal)
                busyIndicator.startAnimating()
            } else {
                isUserInteractionEnabled = true
                setTitleColor(normalTitleColor, for: .normal)
                setImage(normalImage, for: .normal)
                busyIndicator.stopAnimating()
            }
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
        busyIndicator.frame = bounds
        bringSubviewToFront(busyIndicator)
    }
    
    private func prepare() {
        busyIndicator.tintColor = R.color.text_tertiary()!
        busyIndicator.backgroundColor = .clear
        busyIndicator.hidesWhenStopped = true
        busyIndicator.stopAnimating()
        addSubview(busyIndicator)
    }
    
}
