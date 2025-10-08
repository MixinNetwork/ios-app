import UIKit
import QRCode

final class ModernQRCodeView: UIView {
    
    let imageView = UIImageView()
    let activityIndicatorView = ActivityIndicatorView()
    
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
        setContinuousCornerCurve(radius: 14)
    }
    
    func setContinuousCornerCurve(radius: CGFloat) {
        layer.cornerCurve = .continuous
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
    
    func setContent(
        _ content: String,
        dimension: CGFloat,
        activityIndicator: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let size = CGSize(width: dimension, height: dimension)
        setContent(
            content,
            size: size,
            activityIndicator: activityIndicator,
            completion: completion
        )
    }
    
    func setContent(
        _ content: String,
        size: CGSize,
        activityIndicator: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard content != self.content || size != self.size else {
            completion?()
            return
        }
        
        self.content = content
        self.size = size
        if activityIndicator {
            activityIndicatorView.startAnimating()
        }
        imageView.isHidden = true
        
        let scale = AppDelegate.current.mainWindow.screen.scale
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let tintColor = self.tintColor.cgColor
        DispatchQueue.global().async { [qrCodeGenerator] in
            let document = QRCode.Document(utf8String: content,
                                           errorCorrection: .medium,
                                           generator: qrCodeGenerator)
            document.design = {
                let design = QRCode.Design(foregroundColor: tintColor)
                design.shape = {
                    let shape = QRCode.Shape()
                    shape.eye = QRCode.EyeShape.Squircle()
                    shape.onPixels = QRCode.PixelShape.Circle(insetFraction: 0.25)
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
                if activityIndicator {
                    self.activityIndicatorView.stopAnimating()
                }
                self.imageView.isHidden = false
                completion?()
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
        activityIndicatorView.tintColor = R.color.text_tertiary()!
    }
    
}
