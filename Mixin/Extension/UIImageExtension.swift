import UIKit
import CoreGraphics

let jpegCompressionQuality: CGFloat = 0.75

extension UIImage {

    private static let thumbnailMaxWH: CGFloat = 48

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

extension UIImage {

    static func createImageFromString(thumbImage: String?, width: Int?, height: Int?) -> UIImage? {
        guard let thumb = thumbImage else {
            return nil
        }

        let width = width ?? 1
        let height = height ?? 1
        let scale = CGFloat(width) / CGFloat(height)
        let targetWidth: CGFloat = width > height ? Self.thumbnailMaxWH : Self.thumbnailMaxWH * scale
        let targetHeight: CGFloat = width > height ? Self.thumbnailMaxWH / scale : Self.thumbnailMaxWH

        if let image = UIImage(blurHash: thumb, size: CGSize(width: targetWidth, height: targetHeight)) {
            return image
        } else if let imageData = Data(base64Encoded: thumb) {
            return UIImage(data: imageData)
        }

        return nil
    }


    public func blurHashThumbnail() -> String {
        let scaledImage: UIImage
        if max(size.width, size.height) > 48 {
            var targetSize = size.rect(fittingSize: CGSize(width: Self.thumbnailMaxWH, height: Self.thumbnailMaxWH)).size
            targetSize = CGSize(width: max(1, targetSize.width),
                                height: max(1, targetSize.height))
            scaledImage = scaledToSize(newSize: targetSize)
        } else {
            scaledImage = self
        }
        return scaledImage.blurHash()
    }

}
