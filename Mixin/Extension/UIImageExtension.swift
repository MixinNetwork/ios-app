import UIKit
import CoreGraphics

extension UIImage {
    
    convenience init?(qrcode: String, size: CGSize, foregroundColor: UIColor? = nil) {
        guard let filter = CIFilter(name: "CIQRCodeGenerator"), !qrcode.isEmpty else {
            return nil
        }

        filter.setDefaults()
        // To create a QR code from a string or URL, convert it to an NSData object using the NSISOLatin1StringEncoding string encoding.
        let data = qrcode.data(using: String.Encoding.isoLatin1)
        filter.setValue(data, forKey: "inputMessage")

        var outputImage: CIImage?
        if let foregroundColor = foregroundColor {
            guard let colorFilter = CIFilter(name: "CIFalseColor") else {
                return nil
            }
            colorFilter.setValue(filter.outputImage, forKey: "inputImage")
            colorFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1")
            colorFilter.setValue(CIColor(color: foregroundColor), forKey: "inputColor0")
            outputImage = colorFilter.outputImage
        } else {
            outputImage = filter.outputImage
        }

        if let ciImage = outputImage {
            let transform = CGAffineTransform(scaleX: size.width * UIScreen.main.scale / ciImage.extent.width,
                                              y: size.height * UIScreen.main.scale / ciImage.extent.height)
            self.init(ciImage: ciImage.transformed(by: transform))
        } else {
            return nil
        }
    }
    
}
