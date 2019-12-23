import UIKit
import CoreGraphics

let jpegCompressionQuality: CGFloat = 0.75

extension UIImage {
    
    var base64: String? {
        let data = self.jpegData(compressionQuality: jpegCompressionQuality)
        return data?.base64EncodedString()
    }

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

    func scaledToSize(newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContext(newSize)
        draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
    
    func base64Thumbnail(maxLength: CGFloat = 48) -> String {
        let scaledImage: UIImage
        if max(size.width, size.height) > maxLength {
            var targetSize = size.rect(fittingSize: CGSize(width: maxLength, height: maxLength)).size
            targetSize = CGSize(width: max(1, targetSize.width),
                                height: max(1, targetSize.height))
            scaledImage = scaledToSize(newSize: targetSize)
        } else {
            scaledImage = self
        }
        if let ciImage = scaledImage.ciImage, let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(4, forKey: kCIInputRadiusKey)
            if let blurImage = filter.outputImage {
                return UIImage(ciImage: blurImage).base64 ?? ""
            }
        }
        return scaledImage.base64 ?? ""
    }
    
    func scaleForUpload() -> UIImage {
        let maxShortSideLength: CGFloat = 1440
        guard min(size.width, size.height) >= maxShortSideLength else {
            return self
        }
        let maxLongSideLength: CGFloat = 1920
        let scale = CGFloat(size.width) / CGFloat(size.height)
        let targetWidth: CGFloat = size.width > size.height ? maxLongSideLength : maxLongSideLength * scale
        let targetHeight: CGFloat = size.width > size.height ? maxLongSideLength / scale : maxLongSideLength
        return scaledToSize(newSize: CGSize(width: targetWidth, height: targetHeight))
    }

    @discardableResult
    func saveToFile(path: URL, quality: CGFloat = jpegCompressionQuality) -> Bool {
        guard let data = self.jpegData(compressionQuality: quality) else {
            return false
        }
        do {
            try data.write(to: path)
            return true
        } catch {
            return false
        }
    }
    
}
