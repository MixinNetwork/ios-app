import UIKit

class SearchBoxLeftView: UIView {
    
    private let magnifyingGlassImageView = UIImageView(image: R.image.wallet.ic_search())
    private let activityIndicator = SearchBoxActivityIndicator(frame: CGRect(x: 0, y: 0, width: 13, height: 13))
    
    var isBusy = false {
        didSet {
            updateContent()
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
        magnifyingGlassImageView.frame = bounds
        activityIndicator.center = CGPoint(x: bounds.midX - 1, y: bounds.midY - 1)
    }
    
    private func prepare() {
        addSubview(magnifyingGlassImageView)
        activityIndicator.alpha = 0
        activityIndicator.tintColor = .accessoryText
        addSubview(activityIndicator)
    }
    
    private func updateContent() {
        if isBusy {
            activityIndicator.alpha = 1
            activityIndicator.startAnimating()
            UIView.animate(withDuration: 0.2) {
                self.magnifyingGlassImageView.alpha = 0
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.magnifyingGlassImageView.alpha = 1
            }) { (_) in
                guard !self.isBusy else {
                    return
                }
                self.activityIndicator.alpha = 0
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    class SearchBoxActivityIndicator: ActivityIndicatorView {
        
        override var lineWidth: CGFloat {
            return 2
        }
        
        override var contentLength: CGFloat {
            return 13
        }
        
    }
    
}
