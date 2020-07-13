import UIKit
import MLKitVision
import MLKitBarcodeScanning

enum QrCodeDetector {
    
    private static let detector: BarcodeScanner = {
        let options = BarcodeScannerOptions(formats: .qrCode)
        return BarcodeScanner.barcodeScanner(options: options)
    }()
    
    static func detect(in image: UIImage, completion: @escaping (String?) -> Void) {
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        detector.process(visionImage) { (codes, error) in
            if error == nil, let value = codes?.first?.displayValue {
                completion(value)
            } else {
                completion(nil)
            }
        }
    }
    
}
