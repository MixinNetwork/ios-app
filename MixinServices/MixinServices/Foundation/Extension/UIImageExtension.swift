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
    
    public func asBase64Avatar() -> String? {
        let data = jpegData(compressionQuality: JPEGCompressionQuality.medium)
        return data?.base64RawURLEncodedString()
    }
    
    public func imageByScaling(to size: CGSize) -> UIImage? {
        if isAppExtension {
            guard let data = jpegData(compressionQuality: JPEGCompressionQuality.high) else {
                return nil
            }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }
            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: false,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
                kCGImageSourceCreateThumbnailWithTransform: true,
            ]
            guard let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: scaled)
        }
        
        // Do not use UIGraphicsImageRenderer / UIGraphicsBeginImageContextWithOptions here
        // They crash the app on iPhone XS Max with iOS 14.1, when perfoming on a background thread
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
        
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let maybeContext = CGContext(data: nil,
                                     width: Int(orientationResolvedSize.width),
                                     height: Int(orientationResolvedSize.height),
                                     bitsPerComponent: 16,
                                     bytesPerRow: 0, // Use auto-calculated bpr
                                     space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = maybeContext else {
            let infos: [String : Any] = [
                "width": Int(orientationResolvedSize.width),
                "height": Int(orientationResolvedSize.height),
                "space": colorSpace ?? "(null)",
            ]
            let error = MixinServicesError.invalidScalingContextParameter(infos)
            Logger.general.error(category: "ImageScaling", message: "Failed to create CGContext", userInfo: infos)
            reporter.report(error: error)
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: orientationResolvedSize))
        guard let scaled = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: scaled, scale: scale, orientation: imageOrientation)
    }
    
}
