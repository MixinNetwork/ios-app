import UIKit

final class SwapInputAccessoryView: UIView {
    
    protocol Delegate: AnyObject {
        func swapInputAccessoryView(_ view: SwapInputAccessoryView, didSelectMultiplier multiplier: Decimal)
        func swapInputAccessoryViewDidSelectDone(_ view: SwapInputAccessoryView)
    }
    
    @IBOutlet weak var multipliersStackView: UIStackView!
    
    var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        for view in multipliersStackView.arrangedSubviews {
            let backgroundHeight: CGFloat = 32
            let backgroundView = UIView()
            backgroundView.backgroundColor = R.color.background()
            backgroundView.isUserInteractionEnabled = false
            backgroundView.layer.cornerRadius = backgroundHeight / 2
            backgroundView.layer.masksToBounds = true
            insertSubview(backgroundView, belowSubview: multipliersStackView)
            backgroundView.snp.makeConstraints { make in
                make.leading.trailing.centerY.equalTo(view)
                make.height.equalTo(backgroundHeight)
            }
        }
    }
    
    @IBAction func reportMultiplier(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            delegate?.swapInputAccessoryView(self, didSelectMultiplier: 0.25)
        case 1:
            delegate?.swapInputAccessoryView(self, didSelectMultiplier: 0.5)
        default:
            delegate?.swapInputAccessoryView(self, didSelectMultiplier: 1)
        }
    }
    
    @IBAction func reportDone(_ sender: Any) {
        delegate?.swapInputAccessoryViewDidSelectDone(self)
    }
    
}
