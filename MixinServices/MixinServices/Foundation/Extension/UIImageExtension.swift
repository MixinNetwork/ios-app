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
    
    public func imageByScaling(to size: CGSize) -> UIImage {
        // UIGraphicsImageRenderer crashes on size of 3840x2880
        // Don't quite know the reason so we do this in traditional manner
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(origin: .zero, size: size))
        let output = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return output!
    }
    
    public func base64Thumbnail(maxLength: CGFloat = 48) -> String {
        let scaledImage: UIImage
        if max(size.width, size.height) > maxLength {
            var targetSize = size.sizeThatFits(CGSize(width: maxLength, height: maxLength))
            targetSize = CGSize(width: max(1, targetSize.width),
                                height: max(1, targetSize.height))
            scaledImage = self.imageByScaling(to: targetSize)
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
    
}
