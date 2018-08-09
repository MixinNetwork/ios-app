import UIKit
import CoreGraphics
import AVFoundation

let jpegCompressionQuality: CGFloat = 0.75

extension UIImage {
    
    var base64: String? {
        let data = UIImageJPEGRepresentation(self, jpegCompressionQuality)
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

    convenience init?(withFirstFrameOfVideoAtAsset asset: AVAsset) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(value: 0, timescale: 1), actualTime: nil)
            self.init(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    convenience init?(withFirstFrameOfVideoAtURL url: URL) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(value: 0, timescale: 1), actualTime: nil)
            self.init(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    func drawText(text: String, offset: CGPoint, fontSize: CGFloat) -> UIImage {
        guard !text.isEmpty else {
            return self
        }
        let targetWidth = self.size.width
        let targetHeight = self.size.height
        let textColor = UIColor.white
        let textFont = UIFont.systemFont(ofSize: fontSize)
        let textFontAttributes = [NSAttributedStringKey.font: textFont, NSAttributedStringKey.foregroundColor: textColor]
        let string = text as NSString
        let stringSize = string.size(withAttributes: textFontAttributes)
        let textRect = CGRect(x: (targetWidth - stringSize.width) / 2 + offset.x,
                              y: (targetHeight - stringSize.height) / 2 + offset.y,
                              width: stringSize.width,
                              height: stringSize.height)
        UIGraphicsBeginImageContextWithOptions(self.size, false, UIScreen.main.scale)
        draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        string.draw(in: textRect, withAttributes: textFontAttributes)
        defer {
            UIGraphicsEndImageContext()
        }
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }
        return newImage
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

    func getBlurThumbnail(targetWH: CGFloat = 16) -> UIImage {
        let scale = CGFloat(size.width) / CGFloat(size.height)
        let targetWidth: CGFloat = size.width > size.height ? targetWH * scale : targetWH
        let targetHeight: CGFloat = size.width > size.height ? targetWH : targetWH / scale

        let cropImage = scaledToSize(newSize: CGSize(width: targetWidth, height: targetHeight))
        if let ciImage = cropImage.ciImage, let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(4, forKey: kCIInputRadiusKey)
            if let blurImage = filter.outputImage {
                return UIImage(ciImage: blurImage)
            }
        }
        return cropImage
    }

    func toBase64() -> String {
        return UIImagePNGRepresentation(self)?.base64EncodedString() ?? ""
    }

    func scaleForUpload() -> UIImage {
        let maxWH: CGFloat = 1920

        if size.width < maxWH && size.height < maxWH {
            return self
        }

        let scale = CGFloat(size.width) / CGFloat(size.height)
        let targetWidth: CGFloat = size.width > size.height ? maxWH : maxWH * scale
        let targetHeight: CGFloat = size.width > size.height ? maxWH / scale : maxWH
        return scaledToSize(newSize: CGSize(width: targetWidth, height: targetHeight))
    }

    @discardableResult
    func saveToFile(path: URL, quality: CGFloat = jpegCompressionQuality) -> Bool {
        guard let data = UIImageJPEGRepresentation(self, quality) else {
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
