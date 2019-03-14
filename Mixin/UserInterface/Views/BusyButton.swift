import UIKit

class BusyButton: UIButton {
    
    let busyIndicator = UIActivityIndicatorView(style: .gray)
    
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
        busyIndicator.backgroundColor = .white
        busyIndicator.hidesWhenStopped = true
        busyIndicator.stopAnimating()
        addSubview(busyIndicator)
    }
    
}
