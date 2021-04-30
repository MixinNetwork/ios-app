import UIKit
import Photos

protocol AssetQrCodeScanningControllerDelegate: AnyObject {
    
    var previewImageViewContainer: UIView { get }
    
    func assetQrCodeScanningController(_ controller: AssetQrCodeScanningController, didRecognizeString string: String)
    func assetQrCodeScanningControllerDidRecognizeNothing(_ controller: AssetQrCodeScanningController)
    
}

class AssetQrCodeScanningController {
    
    let previewImageView = UIImageView()
    
    weak var delegate: AssetQrCodeScanningControllerDelegate?
    
    private var requestId: PHImageRequestID?
    
    init() {
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.backgroundColor = .black
    }
    
    deinit {
        if let id = requestId {
            PHImageManager.default().cancelImageRequest(id)
        }
    }
    
    func load(asset: PHAsset) {
        if let id = requestId {
            PHImageManager.default().cancelImageRequest(id)
        }
        guard let container = delegate?.previewImageViewContainer else {
            return
        }
        previewImageView.image = nil
        previewImageView.removeFromSuperview()
        container.addSubview(previewImageView)
        previewImageView.snp.makeEdgesEqualToSuperview()
        
        let requestOptions = PHImageRequestOptions()
        requestOptions.version = .current
        requestOptions.isSynchronous = false
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestId = PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestOptions, resultHandler: { [weak self] (image, _) in
            guard let self = self else {
                return
            }
            self.requestId = nil
            self.previewImageView.image = image
            if let detector = qrCodeDetector, let cgImage = image?.cgImage {
                let ciImage = CIImage(cgImage: cgImage)
                for case let feature as CIQRCodeFeature in detector.features(in: ciImage) {
                    guard let string = feature.messageString else {
                        continue
                    }
                    self.delegate?.assetQrCodeScanningController(self, didRecognizeString: string)
                    return
                }
                self.delegate?.assetQrCodeScanningControllerDidRecognizeNothing(self)
            } else {
                self.delegate?.assetQrCodeScanningControllerDidRecognizeNothing(self)
            }
        })
    }
    
    func unload() {
        if let id = requestId {
            PHImageManager.default().cancelImageRequest(id)
        }
        previewImageView.removeFromSuperview()
    }
    
}
