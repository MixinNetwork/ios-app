import UIKit
import QRCode

protocol DepositFieldViewDelegate: AnyObject {
    func depositFieldViewDidCopyContent(_ view: DepositFieldView)
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView)
}

class DepositFieldView: UIView, XibDesignable {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var qrCodeView: ModernQRCodeView!
    @IBOutlet weak var centerWrapperView: UIView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var shadowView: SeparatorShadowView!
    
    @IBOutlet weak var qrCodeWidthConstraint: NSLayoutConstraint!
    
    weak var delegate: DepositFieldViewDelegate?
    
    private lazy var qrCodeGenerator = QRCodeGenerator_External()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    @IBAction func copyAddress(_ sender: Any) {
        UIPasteboard.general.string = contentLabel.text
        delegate?.depositFieldViewDidCopyContent(self)
    }
    
    @IBAction func showQRCodeAction(_ sender: Any) {
        delegate?.depositFieldViewDidSelectShowQRCode(self)
    }
    
    func setQRCode(with content: String) {
        let size = CGSize(width: qrCodeWidthConstraint.constant,
                          height: qrCodeWidthConstraint.constant)
        centerWrapperView.isHidden = true
        qrCodeView.setContent(content, size: size) {
            self.centerWrapperView.isHidden = false
        }
    }
    
    private func loadSubviews() {
        loadXib()
        qrCodeView.setDefaultCornerCurve()
    }
    
}
