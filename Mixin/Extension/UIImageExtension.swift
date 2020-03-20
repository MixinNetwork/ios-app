import UIKit
import CoreGraphics

let jpegCompressionQuality: CGFloat = 0.75

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
    
    func scaledToSticker() -> UIImage {
        let maxWH: CGFloat = 360
        let scale = CGFloat(size.width) / CGFloat(size.height)
        let targetWidth: CGFloat = size.width > size.height ? maxWH : maxWH * scale
        let targetHeight: CGFloat = size.width > size.height ? maxWH / scale : maxWH
        return scaledToSize(newSize: CGSize(width: targetWidth, height: targetHeight))
    }
    
}
