import UIKit
import AVFoundation
import CoreGraphics

public extension UIImage {

    convenience init?(withFirstFrameOf asset: AVAsset) {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let cgImage: CGImage?
        do {
            cgImage = try generator.copyCGImage(at: CMTime(value: 0, timescale: 1), actualTime: nil)
        } catch {
            let size: CGSize
            if let videoTrackNaturalSize = asset.tracks(withMediaType: .video).first?.naturalSize, videoTrackNaturalSize.width > 0, videoTrackNaturalSize.height > 0 {
                size = videoTrackNaturalSize
            } else {
                size = CGSize(width: 1, height: 1)
            }
            let frame = CGRect(origin: .zero, size: size)
            let ciImage = CIImage(color: .black)
            cgImage = CIContext().createCGImage(ciImage, from: frame)
        }
        if let cgImage = cgImage {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }

    convenience init?(withFirstFrameOfVideoAtURL url: URL) {
        let asset = AVURLAsset(url: url)
        self.init(withFirstFrameOf: asset)
    }
    
    @discardableResult
    func saveToFile(path: URL, quality: CGFloat = 0.75) -> Bool {
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

    public var base64: String? {
        let data = self.jpegData(compressionQuality: JPEGCompressionQuality.medium)
        return data?.base64EncodedString()
    }
    
    public func imageByScaling(to size: CGSize) -> UIImage? {
        // Do not use UIGraphicsImageRenderer / UIGraphicsBeginImageContextWithOptions here
        // They crashes the app on iPhone XS Max with iOS 14.1, when perfoming on a background thread
        let cgImage: CGImage
        if let image = self.cgImage {
            cgImage = image
        } else if let ciImage = self.ciImage {
            let context = CIContext(options: nil)
            if let image = context.createCGImage(ciImage, from: ciImage.extent) {
                cgImage = image
            } else {
                return nil
            }
        } else {
            return nil
        }
        
        let orientationResolvedSize: CGSize
        if [.left, .leftMirrored, .right, .rightMirrored].contains(imageOrientation) {
            orientationResolvedSize = CGSize(width: size.height, height: size.width)
        } else {
            orientationResolvedSize = size
        }
        
        guard let context = CGContext(data: nil,
                                      width: Int(orientationResolvedSize.width),
                                      height: Int(orientationResolvedSize.height),
                                      bitsPerComponent: cgImage.bitsPerComponent,
                                      bytesPerRow: 0, // Only a few combinations are not supported by iOS, use auto-calculated bpr
                                      space: cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: cgImage.bitmapInfo.rawValue) else {
            let infos: [String : Any] = [
                "width": Int(orientationResolvedSize.width),
                "height": Int(orientationResolvedSize.height),
                "bitsPerComponent": cgImage.bitsPerComponent,
                "bytesPerRow": 0,
                "space": cgImage.colorSpace?.name ?? "(null)",
                "bitmapInfo": cgImage.bitmapInfo.rawValue
            ]
            let error = MixinServicesError.invalidScalingContextParameter(infos)
            reporter.report(error: error)
            Logger.write(error: error, userInfo: infos)
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: orientationResolvedSize))
        guard let scaled = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: scaled, scale: scale, orientation: imageOrientation)
    }
    
    public func base64Thumbnail(maxLength: CGFloat = 48) -> String {
        let scaledImage: UIImage?
        if max(size.width, size.height) > maxLength {
            var targetSize = size.sizeThatFits(CGSize(width: maxLength, height: maxLength))
            targetSize = CGSize(width: max(1, targetSize.width),
                                height: max(1, targetSize.height))
            scaledImage = self.imageByScaling(to: targetSize)
        } else {
            scaledImage = self
        }
        if let ciImage = scaledImage?.ciImage, let filter = CIFilter(name: "CIGaussianBlur") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(4, forKey: kCIInputRadiusKey)
            if let blurImage = filter.outputImage {
                return UIImage(ciImage: blurImage).base64 ?? ""
            }
        }
        return scaledImage?.base64 ?? ""
    }
    
}
