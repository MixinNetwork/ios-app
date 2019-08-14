import UIKit

protocol DepositFieldViewDelegate: class {
    func depositFieldViewDidCopyContent(_ view: DepositFieldView)
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView)
}

class DepositFieldView: UIView, XibDesignable {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var shadowView: SeparatorShadowView!
    
    weak var delegate: DepositFieldViewDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    @IBAction func copyAction(_ sender: Any) {
        UIPasteboard.general.string = contentLabel.text
        delegate?.depositFieldViewDidCopyContent(self)
    }
    
    @IBAction func showQRCodeAction(_ sender: Any) {
        delegate?.depositFieldViewDidSelectShowQRCode(self)
    }
    
}
