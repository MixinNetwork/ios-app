import UIKit

class BusyButton: UIButton {
    
    let busyIndicator = ActivityIndicatorView()
    
    var isBusy = false {
        didSet {
            isBusy ? busyIndicator.startAnimating() : busyIndicator.stopAnimating()
            isUserInteractionEnabled = !isBusy
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
        busyIndicator.tintColor = .indicatorGray
        busyIndicator.backgroundColor = .clear
        busyIndicator.hidesWhenStopped = true
        busyIndicator.stopAnimating()
        addSubview(busyIndicator)
    }
    
}
