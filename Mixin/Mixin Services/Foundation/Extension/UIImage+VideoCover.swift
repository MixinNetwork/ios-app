import Foundation
import AVFoundation

extension UIImage {
    
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
    
}
