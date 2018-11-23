import UIKit

protocol DepositFieldViewDelegate: class {
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView)
}

class DepositFieldView: UIView, XibDesignable {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var chainImageView: UIImageView!
    
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
        NotificationCenter.default.afterPostOnMain(name: .ToastMessageDidAppear, object: Localized.TOAST_COPIED)
    }
    
    @IBAction func showQRCodeAction(_ sender: Any) {
        delegate?.depositFieldViewDidSelectShowQRCode(self)
    }
    
}
