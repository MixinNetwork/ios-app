import UIKit
import QRCode

protocol DepositFieldViewDelegate: AnyObject {
    func depositFieldViewDidCopyContent(_ view: DepositFieldView)
    func depositFieldViewDidSelectShowQRCode(_ view: DepositFieldView)
}

class DepositFieldView: UIView, XibDesignable {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var qrCodeWrapperView: UIView!
    @IBOutlet weak var qrCodeImageView: UIImageView!
    @IBOutlet weak var assetIconView: AssetIconView!
    @IBOutlet weak var shadowView: SeparatorShadowView!
    
    weak var delegate: DepositFieldViewDelegate?
    
    private var qrCodeContent: String?
    
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
        guard content != qrCodeContent else {
            return
        }
        qrCodeContent = content
        qrCodeImageView.image = nil
        
        let foregroundColor = UIColor.black.cgColor
        let backgroundColor = UIColor.white.cgColor
        let qrCodePixelSize = CGSize(width: qrCodeImageView.bounds.width * AppDelegate.current.mainWindow.screen.scale,
                                     height: qrCodeImageView.bounds.height * AppDelegate.current.mainWindow.screen.scale)
        DispatchQueue.global().async { [weak self, content] in
            let generator = QRCodeGenerator_External()
            let document = QRCode.Document(utf8String: content, errorCorrection: .quantize, generator: generator)
            document.design = {
                let design = QRCode.Design(foregroundColor: foregroundColor, backgroundColor: backgroundColor)
                design.shape = {
                    let shape = QRCode.Shape()
                    shape.eye = QRCode.EyeShape.Squircle()
                    shape.onPixels = QRCode.PixelShape.Circle()
                    return shape
                }()
                return design
            }()
            guard let cgImage = document.cgImage(qrCodePixelSize) else {
                return
            }
            DispatchQueue.main.async {
                guard let self, self.qrCodeContent == content else {
                    return
                }
                self.qrCodeImageView.image = UIImage(cgImage: cgImage)
            }
        }
    }
    
    private func loadSubviews() {
        loadXib()
        qrCodeWrapperView.layer.cornerCurve = .continuous
        qrCodeWrapperView.layer.cornerRadius = 14
        qrCodeWrapperView.layer.masksToBounds = true
    }
    
}
