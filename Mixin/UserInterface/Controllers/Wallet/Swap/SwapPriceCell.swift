import UIKit

final class SwapPriceCell: UICollectionViewCell {
    
    @IBOutlet weak var footerInfoButton: UIButton!
    @IBOutlet weak var footerInfoProgressView: CircularProgressView!
    @IBOutlet weak var footerSpacingView: UIView!
    @IBOutlet weak var swapPriceButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        footerInfoButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 14, weight: .regular),
            adjustForContentSize: true
        )
    }
    
}

extension SwapPriceCell {
    
    enum Content {
        case calculating
        case error(String)
        case price(String)
    }
    
    func setContent(_ content: Content?) {
        switch content {
        case .calculating:
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(R.string.localizable.calculating(), for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .error(let description):
            footerInfoButton.setTitleColor(R.color.red(), for: .normal)
            footerInfoButton.setTitle(description, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        case .price(let price):
            footerInfoButton.setTitleColor(R.color.text_tertiary(), for: .normal)
            footerInfoButton.setTitle(price, for: .normal)
            footerInfoButton.isHidden = false
            footerInfoProgressView.isHidden = false
            footerSpacingView.isHidden = false
            swapPriceButton.isHidden = false
        case nil:
            footerInfoButton.isHidden = true
            footerInfoProgressView.isHidden = true
            footerSpacingView.isHidden = true
            swapPriceButton.isHidden = true
        }
    }
    
}
