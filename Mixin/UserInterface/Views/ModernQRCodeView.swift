import UIKit
import QRCode

final class ModernQRCodeView: UIView {
    
    private let imageView = UIImageView()
    private let activityIndicatorView = ActivityIndicatorView()
    
    private let qrCodeGenerator = QRCodeGenerator_External()
    
    private var content: String?
    private var size: CGSize?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    func setDefaultCornerCurve() {
        layer.cornerCurve = .continuous
        layer.cornerRadius = 14
        layer.masksToBounds = true
    }
    
    func setContent(_ content: String, size: CGSize, completion: @escaping () -> Void) {
        guard content != self.content || size != self.size else {
            completion()
            return
        }
        
        self.content = content
        self.size = size
        activityIndicatorView.startAnimating()
        imageView.isHidden = true
        
        let scale = AppDelegate.current.mainWindow.screen.scale
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let tintColor = self.tintColor.cgColor
        DispatchQueue.global().async { [qrCodeGenerator] in
            let document = QRCode.Document(utf8String: content,
                                           errorCorrection: .quantize,
                                           generator: qrCodeGenerator)
            document.design = {
                let design = QRCode.Design(foregroundColor: tintColor)
                design.shape = {
                    let shape = QRCode.Shape()
                    shape.eye = QRCode.EyeShape.Squircle()
                    shape.onPixels = QRCode.PixelShape.Circle()
                    return shape
                }()
                return design
            }()
            DispatchQueue.main.async {
                guard self.content == content, self.size == size else {
                    return
                }
                if let cgImage = document.cgImage(pixelSize) {
                    self.imageView.image = UIImage(cgImage: cgImage)
                } else {
                    self.imageView.image = nil
                }
                self.activityIndicatorView.stopAnimating()
                self.imageView.isHidden = false
                completion()
            }
        }
    }
    
    private func loadSubviews() {
        addSubview(imageView)
        imageView.snp.makeEdgesEqualToSuperview()
        imageView.backgroundColor = .white
        
        addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        activityIndicatorView.tintColor = .accessoryText
    }
    
}
