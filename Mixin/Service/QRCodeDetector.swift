import UIKit

enum QRCodeDetector {
    
    private static let detector: CIDetector? = {
        let context = CIContext()
        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        return CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options)
    }()
    
    static func detectString(image: UIImage) -> String? {
        guard let detector, let cgImage = image.cgImage else {
            return nil
        }
        let ciImage = CIImage(cgImage: cgImage)
        for case let feature as CIQRCodeFeature in detector.features(in: ciImage) {
            if let string = feature.messageString {
                return string
            }
        }
        return nil
    }
    
    static func detectURL(image: UIImage) -> URL? {
        guard let detector, let cgImage = image.cgImage else {
            return nil
        }
        let ciImage = CIImage(cgImage: cgImage)
        for case let feature as CIQRCodeFeature in detector.features(in: ciImage) {
            if let string = feature.messageString, let url = URL(string: string) {
                return url
            }
        }
        return nil
    }
    
}
